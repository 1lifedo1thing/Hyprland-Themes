# Arquivo criado pelo gerenciador de capas do terminal.
# A função mantém os argumentos e o layout original do fastfetch.
function fastfetch --wraps fastfetch --description 'Fastfetch com capa do perfil ativo'
    set -l capa "$HOME/.config/illogical-impulse/terminal-theme-cover.txt"
    if test -s "$capa"
        set -l imagem (string trim -- (cat "$capa"))
        if test -f "$imagem"
            command fastfetch $argv --logo-type kitty-icat --logo "$imagem" --logo-width 29
            return $status
        end
    end
    command fastfetch $argv
end
