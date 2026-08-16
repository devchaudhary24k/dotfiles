
# fnm
set -l FNM_PATH "$HOME/.local/share/fnm"
if test -x "$FNM_PATH/fnm"
  set PATH "$FNM_PATH" $PATH
  fnm env --shell fish | source
end
