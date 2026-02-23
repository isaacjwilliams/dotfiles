# Show current zmx session in prompt via $ZMX_SESSION.

__zmx_prompt_segment() {
  if [[ -n "${ZMX_SESSION:-}" ]]; then
    printf '%s' "[zmx:${ZMX_SESSION}] "
  fi
}

if [[ "${BASH_IT_THEME:-}" == "bobby" ]]; then
  # Bobby rebuilds PS1 inside prompt_command, so inject the segment directly.
  prompt_command() {
    PS1="\n$(__zmx_prompt_segment)$(battery_char) $(__bobby_clock)"
    PS1+="${yellow?}$(ruby_version_prompt) "
    PS1+="${purple?}\h "
    PS1+="${reset_color?}in "
    PS1+="${green?}\w\n"
    PS1+="${bold_cyan?}$(scm_prompt_char_info) "
    PS1+="${green?}→${reset_color?} "
  }
else
  # Fallback for themes that do not recreate PS1 on each prompt render.
  __zmx_update_prompt_prefix() {
    local marker='${__zmx_prompt_prefix}'
    __zmx_prompt_prefix="$(__zmx_prompt_segment)"
    [[ "$PS1" == "$marker"* ]] || PS1="${__zmx_prompt_prefix}${PS1#"$marker"}"
  }

  if declare -F safe_append_prompt_command >/dev/null; then
    safe_append_prompt_command __zmx_update_prompt_prefix
  else
    PROMPT_COMMAND="__zmx_update_prompt_prefix${PROMPT_COMMAND:+;${PROMPT_COMMAND}}"
  fi
fi
