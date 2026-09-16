#!/usr/bin/env bash
set -Eeuo pipefail

generate_infocyph_header() {
  local describe=" ${1:-DESCRIBE} "
  local figlet_output=''

  if command -v figlet >/dev/null 2>&1; then
    figlet_output="$(figlet -f slant INFOCYPH 2>/dev/null || true)"
  fi
  [[ -n "$figlet_output" ]] || figlet_output='INFOCYPH'

  local figlet_width=0 line len
  while IFS= read -r line; do
    len=${#line}
    (( len > figlet_width )) && figlet_width=$len
  done <<< "$figlet_output"

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

  local box_styles=(
    default dashed dash2 round double heavy parchment simple shell html plus comment php chain
  )
  local selected_box="${box_styles[$RANDOM % ${#box_styles[@]}]}"

  local box_text="$describe"
  local box_text_length=${#box_text}
  local box_width=$((box_text_length + 2))
  local overall_width=$figlet_width
  (( credit_length > overall_width )) && overall_width=$credit_length
  (( box_width > overall_width )) && overall_width=$box_width

  local -a figlet_lines=()
  local line_length pad_total left_pad_count right_pad_count left_pad right_pad
  while IFS= read -r line; do
    line_length=${#line}
    pad_total=$((overall_width - line_length))
    left_pad_count=$((pad_total / 2))
    right_pad_count=$((pad_total - left_pad_count))
    printf -v left_pad '%*s' "$left_pad_count" ''
    printf -v right_pad '%*s' "$right_pad_count" ''
    figlet_lines+=("${left_pad}${line}${right_pad}")
  done <<< "$figlet_output"

  local box_top box_mid box_bot
  local left_padding_box right_padding_box space_pad_left space_pad_right
  local dash_pad_left dash_pad_right horizontal_line
  left_padding_box=$(((overall_width - box_width) / 2))
  right_padding_box=$((overall_width - box_width - left_padding_box))
  printf -v space_pad_left '%*s' "$left_padding_box" ''
  printf -v space_pad_right '%*s' "$right_padding_box" ''
  printf -v dash_pad_left '%*s' "$left_padding_box" ''
  printf -v dash_pad_right '%*s' "$right_padding_box" ''
  dash_pad_left=${dash_pad_left// /-}
  dash_pad_right=${dash_pad_right// /-}
  printf -v horizontal_line '%*s' "$box_text_length" ''
  horizontal_line=${horizontal_line// /-}

  box_top="${space_pad_left}+${horizontal_line}+${space_pad_right}"
  box_mid="${dash_pad_left}|${box_text}|${dash_pad_right}"
  box_bot="${space_pad_left}+${horizontal_line}+${space_pad_right}"

  local credit_left_count credit_right_count credit_left credit_right centered_credit
  credit_left_count=$(((overall_width - credit_length) / 2))
  credit_right_count=$((overall_width - credit_length - credit_left_count))
  printf -v credit_left '%*s' "$credit_left_count" ''
  printf -v credit_right '%*s' "$credit_right_count" ''
  centered_credit="${credit_left}${selected_credit}${credit_right}"

  local work plain styled
  work="$(mktemp -d)"
  plain="$work/plain"
  styled="$work/styled"
  trap 'rm -rf -- "${work:-}"' RETURN INT TERM HUP

  printf '%s\n' "${figlet_lines[@]}" > "$plain"
  printf '%s\n%s\n%s\n%s\n' "$box_top" "$box_mid" "$box_bot" "$centered_credit" >> "$plain"

  if [[ ! -t 1 || -n "${NO_COLOR:-}" ]] || ! command -v chromacat >/dev/null 2>&1; then
    cat "$plain"
    return 0
  fi

  if chromacat -b -B "$selected_box" -O d < "$plain" > "$styled" 2>/dev/null; then
    cat "$styled"
  else
    cat "$plain"
  fi
}

generate_infocyph_header "$@"
