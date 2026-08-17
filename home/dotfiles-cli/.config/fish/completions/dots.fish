function __dots_repository
    if set --query DOTFILES_REPOSITORY
        printf '%s\n' "$DOTFILES_REPOSITORY"
    else
        printf '%s\n' "$HOME/.dotfiles"
    end
end

function __dots_packages
    set --local repository (__dots_repository)
    command find "$repository/home" \
        -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null
end

function __dots_collectors
    set --local repository (__dots_repository)
    command find "$repository/collectors" \
        -mindepth 1 -maxdepth 1 -type f -perm -u=x -printf '%f\n' 2>/dev/null
end

function __dots_machines
    set --local repository (__dots_repository)
    for profile in "$repository"/system/*/security
        if test -x "$profile"
            basename (dirname "$profile")
        end
    end
end

complete --command dots --no-files

complete --command dots --condition __fish_use_subcommand \
    --arguments sync --description 'Refresh packages and app snapshots'
complete --command dots --condition __fish_use_subcommand \
    --arguments snapshot --description 'Refresh package manifests only'
complete --command dots --condition __fish_use_subcommand \
    --arguments add --description 'Adopt one configuration file'
complete --command dots --condition __fish_use_subcommand \
    --arguments link --description 'Link all or selected Stow packages'
complete --command dots --condition __fish_use_subcommand \
    --arguments unlink --description 'Remove managed links'
complete --command dots --condition __fish_use_subcommand \
    --arguments dry-run --description 'Preview Stow operations'
complete --command dots --condition __fish_use_subcommand \
    --arguments scan --description 'Report unmanaged neighbouring files'
complete --command dots --condition __fish_use_subcommand \
    --arguments machine --description 'Host security and recovery profile'
complete --command dots --condition __fish_use_subcommand \
    --arguments tui --description 'Open the interactive terminal interface'
complete --command dots --condition __fish_use_subcommand \
    --arguments status --description 'Show dotfiles Git status'
complete --command dots --condition __fish_use_subcommand \
    --arguments doctor --description 'Validate dependencies and links'
complete --command dots --condition __fish_use_subcommand \
    --arguments help --description 'Show command help'

complete --command dots \
    --condition '__fish_seen_subcommand_from link unlink dry-run' \
    --arguments '(__dots_packages)' --description 'Stow package'
complete --command dots --condition '__fish_seen_subcommand_from add' --force-files
complete --command dots --condition '__fish_seen_subcommand_from sync' \
    --long-option list --description 'List enabled collectors'
complete --command dots --condition '__fish_seen_subcommand_from sync' \
    --long-option only --require-parameter --arguments '(__dots_collectors)' \
    --description 'Run only one collector'
complete --command dots --condition '__fish_seen_subcommand_from machine' \
    --arguments 'list status plan doctor apply' --description 'Machine action'
complete --command dots --condition '__fish_seen_subcommand_from machine' \
    --arguments '(__dots_machines)' --description 'Machine profile'
complete --command dots --condition '__fish_seen_subcommand_from tui' \
    --long-option check --description 'Validate TUI dependencies'
