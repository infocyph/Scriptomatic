#!/usr/bin/env python3
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

def r(path, old, new):
    p=ROOT/path
    t=p.read_text()
    if t.count(old)!=1:
        raise SystemExit(f'{path}: anchor mismatch: {old!r}')
    p.write_text(t.replace(old,new,1))

# PHP original stage presentation.
r('bash/php-cli-setup.sh','install_os_and_php() {\n  local -a','install_os_and_php() {\n  printf \'👉 Installing base Alpine packages and PHP extensions…\\n\'\n  local -a')
r('bash/php-cli-setup.sh','configure_fpm_includes_and_dirs() {\n  local fpm_conf','configure_fpm_includes_and_dirs() {\n  printf \'👉 Configuring PHP-FPM includes (/usr/local/etc/php-fpm.conf)…\\n\'\n  local fpm_conf')
r('bash/php-cli-setup.sh','configure_required_ini() {\n  atomic_write','configure_required_ini() {\n  printf \'👉 Writing PHP CA bundle ini…\\n\'\n  atomic_write')
r('bash/php-cli-setup.sh','configure_msmtp() {\n  atomic_write','configure_msmtp() {\n  printf \'👉 Writing msmtp config (/etc/msmtprc)…\\n\'\n  atomic_write')
r('bash/php-cli-setup.sh','configure_composer_home() {\n  atomic_write','configure_composer_home() {\n  printf \'👉 Configuring Composer home (%s)…\\n\' "$COMPOSER_HOME_VERSIONED"\n  atomic_write')
r('bash/php-cli-setup.sh','install_helper_scripts() {\n  install_toolset_helper','install_helper_scripts() {\n  printf \'👉 Installing helper scripts…\\n\'\n  install_toolset_helper')
r('bash/php-cli-setup.sh','set_banner_hook() {\n  atomic_write','set_banner_hook() {\n  printf \'👉 Setting global banner hook…\\n\'\n  atomic_write')
r('bash/php-cli-setup.sh','create_user() {\n  local group_name','create_user() {\n  printf \'👉 Ensuring user %s (UID=%s, GID=%s) exists…\\n\' "$USERNAME" "$SCRIPTOMATIC_UID" "$SCRIPTOMATIC_GID"\n  local group_name')
r('bash/php-cli-setup.sh','  [[ "$SCRIPTOMATIC_OH_MY_BASH" == 1 ]] || return 0\n  [[ -d "${HOME_DIR}/.oh-my-bash" ]] && return 0','  [[ "$SCRIPTOMATIC_OH_MY_BASH" == 1 ]] || return 0\n  printf \'👉 Configuring Oh My Bash for %s…\\n\' "$USERNAME"\n  [[ -d "${HOME_DIR}/.oh-my-bash" ]] && return 0')
r('bash/php-cli-setup.sh','  if ! line_in_file \'show-banner "PHP\' "$BASHRC"; then\n    cat >>','  if ! line_in_file \'show-banner "PHP\' "$BASHRC"; then\n    printf \'👉 Adding banner snippet to .bashrc…\\n\'\n    cat >>')
r('bash/php-cli-setup.sh','run_alias_maker() {\n  run_as_user','run_alias_maker() {\n  printf \'👉 Applying aliases via alias-maker…\\n\'\n  run_as_user')

# Node original stage presentation.
r('bash/node-cli-setup.sh','install_os() {\n  local -a','install_os() {\n  printf \'👉 Installing base Alpine packages…\\n\'\n  local -a')
r('bash/node-cli-setup.sh','install_helper_scripts() {\n  install_toolset_helper','install_helper_scripts() {\n  printf \'👉 Installing helper scripts…\\n\'\n  install_toolset_helper')
r('bash/node-cli-setup.sh','set_banner_hook() {\n  atomic_write','set_banner_hook() {\n  printf \'👉 Setting global banner hook…\\n\'\n  atomic_write')
r('bash/node-cli-setup.sh','create_user() {\n  local group_name','create_user() {\n  printf \'👉 Ensuring user %s (UID=%s, GID=%s) exists…\\n\' "$USERNAME" "$SCRIPTOMATIC_UID" "$SCRIPTOMATIC_GID"\n  local group_name')
r('bash/node-cli-setup.sh','configure_node() {\n  local -a','configure_node() {\n  printf \'👉 Configuring Node tooling…\\n\'\n  local -a')
r('bash/node-cli-setup.sh','  [[ "$SCRIPTOMATIC_OH_MY_BASH" == 1 ]] || return 0\n  command -v git','  [[ "$SCRIPTOMATIC_OH_MY_BASH" == 1 ]] || return 0\n  printf \'👉 Configuring Oh My Bash for %s…\\n\' "$USERNAME"\n  command -v git')
r('bash/node-cli-setup.sh','  if ! line_in_file \'show-banner "Node\' "$BASHRC"; then\n    cat >>','  if ! line_in_file \'show-banner "Node\' "$BASHRC"; then\n    printf \'👉 Adding banner snippet to .bashrc…\\n\'\n    cat >>')
r('bash/node-cli-setup.sh','run_alias_maker() {\n  run_as_user','run_alias_maker() {\n  printf \'👉 Applying aliases via alias-maker…\\n\'\n  run_as_user')
print('stage output restored')
