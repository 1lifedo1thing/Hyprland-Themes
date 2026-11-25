#include "accountlogin.hpp"
#include <QDebug>
#include <QDateTime>
#include <QDialog>
#include <QHBoxLayout>
#include <QLabel>
#include <QPointer>
#include <QPushButton>
#include <QResizeEvent>
#include <QSet>
#include <QTimer>
#include <QUuid>
#include <QVBoxLayout>
#include <QWebEngineDownloadRequest>
#include <QWebEngineNewWindowRequest>
#include <QWebEnginePage>
#include <QWebEnginePermission>
#include <QWebEngineProfile>
#include <QWebEngineScript>
#include <QWebEngineSettings>
#include <QWebEngineView>

namespace account {
namespace {
QString q(std::string_view s) { return QString::fromUtf8(s.data(), s.size()); }
double now() { return h::fromUnix(QDateTime::currentMSecsSinceEpoch() / 1000.); }
class View final : public QWebEngineView {
public:
    using QWebEngineView::QWebEngineView;
protected:
    void resizeEvent(QResizeEvent *event) override {
        QWebEngineView::resizeEvent(event);
        setZoomFactor(h::login_policy::pageZoom(event->size().width()));
    }
};
class Page final : public QWebEnginePage {
public:
    Page(QWebEngineProfile *profile, QObject *parent, std::shared_ptr<h::LoginSession> session, bool popup)
        : QWebEnginePage(profile, parent), m_session(std::move(session)), m_popup(popup) {}
protected:
    bool acceptNavigationRequest(const QUrl &url, NavigationType, bool mainFrame) override {
        return m_session->allowNavigation(url.toString(QUrl::FullyEncoded).toStdString(), mainFrame, m_popup);
    }
    void javaScriptConsoleMessage(JavaScriptConsoleMessageLevel, const QString &, int, const QString &) override {}
    QStringList chooseFiles(FileSelectionMode, const QStringList &, const QStringList &) override { return {}; }
private:
    std::shared_ptr<h::LoginSession> m_session;
    bool m_popup;
};
class QtLogin final : public QObject, public Login {
public:
    QtLogin(QObject *owner, std::function<void()> requested, std::function<void()> finished,
            std::function<endfield::core::Language()> language)
        : QObject(nullptr), m_owner(owner), m_requested(std::move(requested)), m_finished(std::move(finished)), m_language(std::move(language)) {
        m_clock.setInterval(500);
        connect(&m_clock, &QTimer::timeout, this, [this] {
            if (!m_session) return;
            if (const auto failure = m_session->deadline(now())) { finish({}, *failure); return; }
            if (m_status) m_status->setText(q(m_session->statusText(m_language())));
            for (const auto &page : std::as_const(m_pages)) if (page && !page->isLoading()) readSession(page);
        });
    }
    ~QtLogin() override { m_completion = {}; m_finished = {}; finish({}, h::LoginFailure::cancelled); }
    bool isPresenting() const override { return bool(m_session); }
    void present(h::Region region, std::function<void(std::optional<h::LoginResult>, h::LoginFailure)> completion) override {
        if (m_session) { QTimer::singleShot(0, m_owner, [completion] { completion({}, h::LoginFailure::alreadyPresenting); }); return; }
        m_session = std::make_shared<h::LoginSession>(region, QUuid::createUuid().toString(QUuid::WithoutBraces).toStdString());
        m_completion = std::move(completion);
        m_requested(); // The HUD closes before the native official-site window takes focus.
    }
    void cancel() override { finish({}, h::LoginFailure::cancelled); }
    void show() override {
        if (!m_session || m_dialog) return;
        const auto strings = h::LoginSession::strings(m_session->region(), m_language(), h::AccountWording::linuxDesktop);
        auto *dialog = new QDialog; m_dialog = dialog; dialog->setAttribute(Qt::WA_DeleteOnClose);
        QString title = q(strings.title); title.replace("EndfieldHUD", "HyprEndfield"); dialog->setWindowTitle(title); dialog->resize(900, 680);
        auto *layout = new QVBoxLayout(dialog);
        auto *heading = new QLabel(q(strings.consentTitle), dialog); heading->setWordWrap(true); layout->addWidget(heading);
        auto *detail = new QLabel(q(strings.consentDetail), dialog); detail->setWordWrap(true); layout->addWidget(detail);
        layout->addStretch();
        auto *buttons = new QHBoxLayout; layout->addLayout(buttons);
        auto *proceed = new QPushButton(q(strings.continueLabel), dialog); auto *cancelButton = new QPushButton(q(strings.cancelLabel), dialog);
        buttons->addWidget(proceed); buttons->addWidget(cancelButton);
        connect(cancelButton, &QPushButton::clicked, dialog, &QDialog::reject);
        connect(dialog, &QDialog::finished, this, [this, session = m_session] { QTimer::singleShot(0, this, [this, session] { if (m_session == session) finish({}, h::LoginFailure::cancelled); }); });
        connect(proceed, &QPushButton::clicked, this, [this, dialog, layout, heading, detail, proceed] {
            if (!m_session || !m_session->consent(now())) return;
            heading->hide(); detail->hide(); proceed->hide(); delete layout->takeAt(2);
            m_profile = new QWebEngineProfile(this); // unnamed, off-the-record; never reuse a user's browser profile
            m_profile->setPersistentCookiesPolicy(QWebEngineProfile::NoPersistentCookies);
            connect(m_profile, &QWebEngineProfile::downloadRequested, this, [](QWebEngineDownloadRequest *request) { request->cancel(); });
            auto *view = new View(dialog); layout->insertWidget(0, view, 1);
            setup(view, false); m_main = view;
            m_status = new QLabel(dialog); m_status->setWordWrap(true); layout->insertWidget(1, m_status);
            auto *probe = new QLabel(dialog); probe->setWordWrap(true);
            layout->insertWidget(2, probe); m_probeLabel = probe;
            auto *retry = new QPushButton(q(h::LoginSession::strings(m_session->region(), m_language()).retryLabel), dialog);
            layout->insertWidget(2, retry);
            connect(retry, &QPushButton::clicked, this, [this] {
                if (!m_session || !m_main || !m_session->retry(now())) return;
                const auto popups = m_popups; for (auto popup : popups) if (popup) popup->close();
                m_main->load(QUrl(q(h::login_policy::siteURL(m_session->region()))));
            });
            view->load(QUrl(q(h::login_policy::siteURL(m_session->region())))); m_clock.start();
        });
        dialog->show(); dialog->raise(); dialog->activateWindow();
    }
private:
    void showProbe(const QString &summary) {
        // HYPR_ENDFIELD_ACCOUNT_LINK_19A: statuses only, never token/cookie values.
        if (summary == m_lastProbe) return;
        m_lastProbe = summary;
        if (m_probeLabel) m_probeLabel->setText(summary);
        qInfo().noquote() << "[hyprendfield-account]" << summary;
    }
    void setup(QWebEngineView *view, bool popup) {
        auto *page = new Page(m_profile, view, m_session, popup); view->setPage(page); m_pages.push_back(page);
        page->settings()->setAttribute(QWebEngineSettings::JavascriptCanOpenWindows, true);
        page->settings()->setAttribute(QWebEngineSettings::LocalContentCanAccessFileUrls, false);
        page->setAudioMuted(true); page->setZoomFactor(h::login_policy::pageZoom(view->width()));
        connect(page, &QWebEnginePage::permissionRequested, this, [](QWebEnginePermission permission) { permission.deny(); });
        connect(page, &QWebEnginePage::windowCloseRequested, view->window(), &QWidget::close);
        connect(page, &QWebEnginePage::loadStarted, this, [this, popup] { if (m_session && !popup) m_session->pageStarted(now()); });
        connect(page, &QWebEnginePage::loadFinished, this, [this, page, popup](bool ok) {
            if (!m_session) return;
            if (ok) {
                m_session->pageFinished(!popup, page->url().host().toStdString());
                // Keep the source's official login-button selection. Only message delivery
                // differs: Qt reads the same credential script in an isolated JS world.
                QString script = directScript(m_session->region(), m_session->nonce());
                page->runJavaScript(script, QWebEngineScript::ApplicationWorld); readSession(page);
            } else m_session->pageFailed(-1, false);
        });
        connect(page, &QWebEnginePage::renderProcessTerminated, this, [this] { if (m_session) m_session->processFailed(); });
        connect(page, &QWebEnginePage::newWindowRequested, this, [this, page](QWebEngineNewWindowRequest &request) {
            if (!m_session || !m_session->allowPopup(request.requestedUrl().toString().toStdString(), page->url().toString().toStdString())) return;
            auto *dialog = new QDialog(m_dialog); dialog->setAttribute(Qt::WA_DeleteOnClose); dialog->resize(900, 680);
            dialog->setWindowTitle(m_dialog->windowTitle()); auto *layout = new QVBoxLayout(dialog); auto *view = new View(dialog);
            layout->addWidget(view); setup(view, true); m_popups.push_back(dialog);
            connect(dialog, &QDialog::finished, this, [this] { if (m_session) m_session->popupClosed(); });
            request.openIn(view->page()); dialog->show();
        });
    }
    void readSession(QWebEnginePage *page) {
        if (!m_session || m_reading.contains(page)) return;
        const auto url = page->url().toString(QUrl::FullyEncoded).toStdString();
        if (!h::login_policy::acceptsCredentialOrigin(h::parseURL(url), m_session->region())) {
            if (page->url().scheme() == QStringLiteral("https"))
                showProbe(QStringLiteral("Diagnóstico (sem segredos): origem não autorizada para leitura: ")
                          + page->url().host());
            return;
        }
        QString script = credentialScript(m_session->region(), m_session->nonce());
        const auto session = m_session; QPointer<QWebEnginePage> safe(page); QPointer<QtLogin> self(this);
        m_reading.insert(page);
        page->runJavaScript(script, QWebEngineScript::ApplicationWorld, [self, safe, session, url](const QVariant &result) {
            if (!self) return;
            if (safe) self->m_reading.remove(safe);
            if (!safe || self->m_session != session || safe->url().toString(QUrl::FullyEncoded).toStdString() != url) return;
            const auto bytes = result.toString().toUtf8();
            if (bytes.isEmpty() || bytes.size() > 16384) {
                self->showProbe(QStringLiteral("Diagnóstico (sem segredos): sem resposta do JavaScript do site."));
                return;
            }
            try {
                const auto message = h::Json::parse(bytes.toStdString(), 16384);
                if (message["status"].isString()) {
                    if (message["status"].string() == "pending") {
                        const auto present = [&](const char* key) {
                            return message[key].isBool() && message[key].boolean();
                        };
                        self->showProbe(QStringLiteral("Diagnóstico (sem segredos): cred=%1, token=%2, dispositivo=%3")
                            .arg(present("cred") ? QStringLiteral("sim") : QStringLiteral("não"))
                            .arg(present("signingToken") ? QStringLiteral("sim") : QStringLiteral("não"))
                            .arg(present("deviceID") ? QStringLiteral("sim") : QStringLiteral("não")));
                    } else {
                        self->showProbe(QStringLiteral("Diagnóstico (sem segredos): leitura fora da origem oficial."));
                    }
                    return;
                }
                if (!message["channel"].isString() || message["channel"].string() != h::login_policy::messageName)
                    return;
                if (auto value = session->credentialMessage(message["body"], true, url, url)) {
                    self->showProbe(value->deviceID
                        ? QStringLiteral("Diagnóstico (sem segredos): sessão completa validada.")
                        : QStringLiteral("Diagnóstico (sem segredos): identificador ausente; renovação pela API oficial."));
                    QTimer::singleShot(0, self, [self, session, value] {
                        if (self && self->m_session == session) self->finish(value, h::LoginFailure::cancelled);
                    });
                } else {
                    self->showProbe(QStringLiteral("Diagnóstico (sem segredos): sessão encontrada, mas validação rejeitou."));
                }
            } catch (...) {
                self->showProbe(QStringLiteral("Diagnóstico (sem segredos): resposta não interpretável."));
            } // Never emit the credential body, browser console or page HTML.
        });
    }
    void finish(std::optional<h::LoginResult> result, h::LoginFailure failure) {
        if (!m_session) return;
        m_clock.stop(); auto session = std::move(m_session);
        session->finish(result ? h::LoginSession::Outcome::completed : failure == h::LoginFailure::expired ? h::LoginSession::Outcome::expired : h::LoginSession::Outcome::cancelled);
        m_reading.clear(); m_pages.clear(); m_popups.clear(); m_main = nullptr; m_status = nullptr; m_probeLabel = nullptr; m_lastProbe.clear();
        if (m_dialog) { disconnect(m_dialog, nullptr, this, nullptr); delete m_dialog; m_dialog = nullptr; }
        delete m_profile; m_profile = nullptr;
        auto callback = std::move(m_completion); const auto finished = m_finished;
        if (callback) QTimer::singleShot(0, m_owner, [callback = std::move(callback), result = std::move(result), failure, finished] { callback(result, failure); if (finished) finished(); });
    }
    QPointer<QObject> m_owner;
    std::function<void()> m_requested, m_finished;
    std::function<endfield::core::Language()> m_language;
    std::function<void(std::optional<h::LoginResult>, h::LoginFailure)> m_completion;
    std::shared_ptr<h::LoginSession> m_session;
    QPointer<QDialog> m_dialog;
    QPointer<QWebEngineView> m_main;
    QPointer<QLabel> m_status;
    QPointer<QLabel> m_probeLabel;
    QString m_lastProbe;
    QWebEngineProfile *m_profile = nullptr;
    QList<QPointer<QWebEnginePage>> m_pages;
    QList<QPointer<QDialog>> m_popups;
    QSet<QWebEnginePage *> m_reading;
    QTimer m_clock;
};
}
QString credentialScript(h::Region region, std::string_view nonce) {
    // HYPR_ENDFIELD_ACCOUNT_LINK_19A: read an already authenticated official
    // community session in the same origin. No credentials are ever logged.
    // Session acceptance is still checked by LoginSession::credentialMessage.
    QString script = QStringLiteral(R"ENDFIELD_JS((() => {
      if (window.top !== window || location.origin !== '__ENDFIELD_ORIGIN__')
        return JSON.stringify({status: 'outside-origin'});
      const valid = value => typeof value === 'string'
          && /^[\x21-\x7e]{1,4096}$/.test(value);
      const get = (key, where) => {
        try { return where.getItem(key); } catch (_) { return null; }
      };
      const read = key => {
        const values = [];
        for (const storage of ['localStorage', 'sessionStorage']) {
          try { values.push(get(key, window[storage])); } catch (_) { values.push(null); }
        }
        return values;
      };
      const extract = (raw, field) => {
        if (typeof raw !== 'string' || raw.length < 1 || raw.length > 16384) return null;
        const clean = raw.trim();
        if (!clean) return null;
        try {
          const parsed = JSON.parse(clean);
          if (typeof parsed === 'string') return valid(parsed) ? parsed : null;
          if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
            const value = parsed[field];
            return valid(value) ? value : null;
          }
          return null;
        } catch (_) {
          // A plain credential is expected; a broken JSON wrapper is not.
          if (clean.startsWith('{') || clean.startsWith('[') || clean.startsWith('"')) return null;
          return valid(clean) ? clean : null;
        }
      };
      const pick = (...values) => values.find(valid) || null;
      const cred = pick(...read('SK_OAUTH_CRED_KEY').map(v => extract(v, 'cred')),
                        ...read('SK_ADMIN_CRED_KEY').map(v => extract(v, 'cred')));
      const signingToken = pick(...read('SK_TOKEN_CACHE_KEY').map(v => extract(v, 'token')));
      const deviceID = pick(...read('SK_SHUMEI_DEVICE_ID_KEY').map(v => extract(v, 'id')));
      const present = { cred: valid(cred), signingToken: valid(signingToken),
                        deviceID: valid(deviceID) };
      if (!present.cred || !present.signingToken)
        return JSON.stringify({status:'pending', ...present});
      // HYPR_ENDFIELD_ACCOUNT_LINK_19B: missing dId, but the official login
      // returned a cred and signing token. Use the backend's existing cred-only
      // refresh endpoint, rather than creating a fake device identifier.
      if (!present.deviceID)
        return JSON.stringify({
          channel: 'endfieldCommunityCredential',
          body: {nonce:'__ENDFIELD_NONCE__', cred}
        });
      return JSON.stringify({
        channel: 'endfieldCommunityCredential',
        body: {nonce:'__ENDFIELD_NONCE__', cred, signingToken, deviceID}
      });
    })())ENDFIELD_JS");
    script.replace(QStringLiteral("__ENDFIELD_ORIGIN__"),
                   q(region == h::Region::mainland ? "https://www.skland.com" : "https://www.skport.com"));
    script.replace(QStringLiteral("__ENDFIELD_NONCE__"), q(nonce));
    return script;
}
QString directScript(h::Region region, std::string_view nonce) {
    QString script = q(h::login_policy::directLoginScript(region, nonce));
    script.replace("window.chrome.webview.postMessage", "void");
    return script;
}
std::unique_ptr<Login> makeLogin(QObject *owner, std::function<void()> requested, std::function<void()> finished,
    std::function<endfield::core::Language()> language) {
    return std::make_unique<QtLogin>(owner, std::move(requested), std::move(finished), std::move(language));
}
}
