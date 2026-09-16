#!/usr/bin/env bash
set -u

generate_infocyph_header() {
  local describe=" ${1:-DESCRIBE} "

  if ! command -v figlet >/dev/null 2>&1; then
    printf 'INFOCYPH\n%s\n' "$describe"
    return 0
  fi

  local figlet_output
  if ! figlet_output="$(figlet -f slant "INFOCYPH" 2>/dev/null)" || [[ -z "$figlet_output" ]]; then
    printf 'INFOCYPH\n%s\n' "$describe"
    return 0
  fi

  local figlet_width=0
  local line len
  while IFS= read -r line; do
    len=${#line}
    (( len > figlet_width )) && figlet_width=$len
  done <<<"$figlet_output"

  local credits=(
    "Innovation at its core."
    "Powered by passion."
    "Crafting excellence."
    "Unleashing creativity."
    "Where ideas come to life."
    "Driven by curiosity."
    "Engineering the future."
    "Code with purpose."
    "Empowering innovation."
    "Simplicity meets brilliance."
    "Ideas that inspire."
    "Invent. Iterate. Impact."
    "Fueling digital dreams."
    "Excellence is our habit."
    "Crafted with precision."
    "Think bold. Build smart."
    "Rooted in vision."
    "Designing tomorrow."
    "Innovation never sleeps."
    "Beyond the ordinary."
    "Code that matters."
    "Dream. Build. Repeat."
    "Solutions, not shortcuts."
    "From vision to reality."
    "Sharpening the edge of tech."
    "Open source. Open minds."
    "Powered by community."
    "Collaborate. Contribute. Create."
    "Freedom to build."
    "Code belongs to everyone."
    "Community is our compiler."
    "Transparency is the backbone."
    "Built in the open."
    "Shared code, shared progress."
    "Open hearts. Open repos."
    "Fork it, fix it, fuel it."
    "Innovation through collaboration."
    "The source of all progress."
    "Together, we build better."
    "By devs, for devs."
    "The power of many minds."
    "Push, pull, empower."
    "Trust the open way."
    "License to innovate."
    "Where sharing sparks growth."
  )
  local selected_credit="${credits[$RANDOM % ${#credits[@]}]}"
  local credit_length=${#selected_credit}

  local box_styles=(default dashed dash2 round double heavy parchment simple shell html plus comment php chain)
  local selected_box="${box_styles[$RANDOM % ${#box_styles[@]}]}"

  local box_text="$describe"
  local box_text_length=${#box_text}
  local box_width=$((box_text_length + 2))
  local overall_width=$figlet_width
  (( credit_length > overall_width )) && overall_width=$credit_length
  (( box_width > overall_width )) && overall_width=$box_width

  local centered_figlet=""
  local -a figlet_lines=()
  while IFS= read -r line; do
    local line_length=${#line}
    local pad_total=$((overall_width - line_length))
    local left_pad=$((pad_total / 2))
    local right_pad=$((pad_total - left_pad))
    figlet_lines+=("$(printf '%*s' "$left_pad" '')${line}$(printf '%*s' "$right_pad" '')")
  done <<<"$figlet_output"
  centered_figlet="$(printf '%s\n' "${figlet_lines[@]}")"

  local left_padding_box=$(((overall_width - box_width) / 2))
  local right_padding_box=$((overall_width - box_width - left_padding_box))
  (( left_padding_box < 0 )) && left_padding_box=0
  (( right_padding_box < 0 )) && right_padding_box=0

  local space_pad_left space_pad_right dash_pad_left dash_pad_right horizontal_line
  space_pad_left="$(printf '%*s' "$left_padding_box" '')"
  space_pad_right="$(printf '%*s' "$right_padding_box" '')"
  dash_pad_left="$(printf '%*s' "$left_padding_box" '' | tr ' ' '-')"
  dash_pad_right="$(printf '%*s' "$right_padding_box" '' | tr ' ' '-')"
  horizontal_line="$(printf '%*s' "$box_text_length" '' | tr ' ' '-')"

  local box_top="${space_pad_left}+${horizontal_line}+${space_pad_right}"
  local box_mid="${dash_pad_left}|${box_text}|${dash_pad_right}"
  local box_bot="${space_pad_left}+${horizontal_line}+${space_pad_right}"

  local left_spaces=$(((overall_width - credit_length) / 2))
  local right_spaces=$((overall_width - credit_length - left_spaces))
  (( left_spaces < 0 )) && left_spaces=0
  (( right_spaces < 0 )) && right_spaces=0
  local centered_credit="$(printf '%*s' "$left_spaces" '')${selected_credit}$(printf '%*s' "$right_spaces" '')"

  local rendered
  rendered="$(printf '%s\n%s\n%s\n%s\n%s\n' \
    "$centered_figlet" "$box_top" "$box_mid" "$box_bot" "$centered_credit")"

  if [[ -t 1 && -z "${NO_COLOR:-}" ]] && command -v chromacat >/dev/null 2>&1; then
    printf '%s' "$rendered" | chromacat -b -B "$selected_box" -O d 2>/dev/null || printf '%s' "$rendered"
  else
    printf '%s' "$rendered"
  fi

  return 0
}

generate_infocyph_header "$@" || true
