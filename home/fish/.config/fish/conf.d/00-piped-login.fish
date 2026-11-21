# A login shell with a script piped in and no command, which is what VS Code
# Remote-SSH (and editors like it) start, runs the script in bash instead.
# fish reads piped input to the end before running any of it, and those tools
# keep the pipe open, so under fish the script never runs and they time out.
# Terminals (interactive), `ssh host 'cmd'` and `su -` (-c) all stay in fish.
if status is-login; and not status is-interactive; and not test -t 0
    and test (count (string split0 </proc/$fish_pid/cmdline)) -eq 1
    exec bash --login
end
