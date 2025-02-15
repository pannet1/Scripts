xontribs =  ['argcomplete', 'avox', 'abbrevs', 'back2dir', 'broot', 'clp', 'debug-tools', 'distributed', 'cmd_done',  'fzf-widgets', 'gitinfo', 'gruvbox', 'hist_navigator', 'histcpy', 'kitty', 'mpl', 'onepath', 'output_search', 'powerline3', 'prompt_vi_mode', 'pyenv','readable-traceback', 'sh', 'ssh_agent', 'up', 'xlsd','vox', 'z']
xonshes = ['autoxsh', 'autovox', 'vox_tabcomplete']

 pip uninstall onefetch pyperclip repassh --user --break-system-packages

for item in xontribs:
  item = "xontrib-"+item
  pip uninstall @(item) --user --break-system-packages

for xs in xonshes:
  xs = "xonsh-"+xs
  pip uninstall @(xs)  --user --break-system-packages


