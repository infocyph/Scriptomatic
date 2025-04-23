#!/bin/bash

generate_infocyph_header() {
  local title="INFOCYPH"
  local describe=" ${1:-DESCRIBE} "

  # Generate figlet output for the title
  local figlet_output
  figlet_output=$(figlet -f slant "$title")

  # Compute maximum length of figlet output lines
  local figlet_width=0
  while IFS= read -r line; do
    local len=${#line}
    (( len > figlet_width )) && figlet_width=$len
  done <<< "$figlet_output"

  # Prepare Credit Information
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
  "default"
  "dashed"
  "dash2"
  "round"
  "double"
  "heavy"
  "parchment"
  "simple"
  "shell"
  "html"
  "plus"
  "comment"
  "php"
  "chain"
  )
  local selected_box="${box_styles[$RANDOM % ${#box_styles[@]}]}"

  # Prepare DESCRIBE Box
  local box_text="$describe"
  local box_text_length=${#box_text}
  local box_width=$(( box_text_length + 2 ))  # plus vertical borders

  # Determine Overall Width:
  # Overall width is the maximum of figlet_width, credit_length, and box_width.
  local overall_width=$figlet_width
  (( credit_length > overall_width )) && overall_width=$credit_length
  (( box_width > overall_width )) && overall_width=$box_width

  # Center-align Figlet Output using an array
  local centered_figlet=""
  local -a figlet_lines
  while IFS= read -r line; do
    local line_length=${#line}
    local pad_total=$(( overall_width - line_length ))
    local left_pad=$(( pad_total / 2 ))
    local right_pad=$(( pad_total - left_pad ))
    local left_spaces
    left_spaces=$(printf '%*s' "$left_pad" "")
    local right_spaces
    right_spaces=$(printf '%*s' "$right_pad" "")
    figlet_lines+=("${left_spaces}${line}${right_spaces}")
  done <<< "$figlet_output"
  centered_figlet=$(printf "%s\n" "${figlet_lines[@]}")
  # Optionally remove a trailing newline:
  centered_figlet=$(echo -n "$centered_figlet")

  # Build DESCRIBE Box with dash padding for the middle line only
  local box_top=""
  local box_mid=""
  local box_bot=""
  if (( box_width > overall_width )); then
    box_mid="$box_text"
  else
    local left_padding_box=$(( (overall_width - box_width) / 2 ))
    local right_padding_box=$(( overall_width - box_width - left_padding_box ))

    # For top and bottom borders, use space padding for left/right
    local space_pad_left
    space_pad_left=$(printf '%*s' "$left_padding_box" "")
    local space_pad_right
    space_pad_right=$(printf '%*s' "$right_padding_box" "")

    # For the middle line, use dash padding on the sides
    local dash_pad_left
    dash_pad_left=$(printf '%*s' "$left_padding_box" "" | tr ' ' '-')
    local dash_pad_right
    dash_pad_right=$(printf '%*s' "$right_padding_box" "" | tr ' ' '-')

    local horizontal_line
    horizontal_line=$(printf '%*s' "$box_text_length" "" | tr ' ' '-')

    box_top="${space_pad_left}+${horizontal_line}+${space_pad_right}"
    box_mid="${dash_pad_left}|${box_text}|${dash_pad_right}"
    box_bot="${space_pad_left}+${horizontal_line}+${space_pad_right}"
  fi

  # Center-align the Credit
  local centered_credit=""
  if (( credit_length >= overall_width )); then
    centered_credit="$selected_credit"
  else
    local left_spaces=$(( (overall_width - credit_length) / 2 ))
    local right_spaces=$(( overall_width - credit_length - left_spaces ))
    local left_pad
    left_pad=$(printf '%*s' "$left_spaces" "")
    local right_pad
    right_pad=$(printf '%*s' "$right_spaces" "")
    centered_credit="${left_pad}${selected_credit}${right_pad}"
  fi

  # Assemble Final Output
  if [ -n "$box_top" ] && [ -n "$box_mid" ] && [ -n "$box_bot" ]; then
    printf "%b\n%s\n%s\n%s\n%s\n" \
      "$centered_figlet" \
      "$box_top" \
      "$box_mid" \
      "$box_bot" \
      "$centered_credit"
  else
    printf "%b\n%s\n%s\n" \
      "$centered_figlet" \
      "$box_mid" \
      "$centered_credit"
  fi | chromacat -b -B "$selected_box" -O d
}

generate_infocyph_header "$@"
