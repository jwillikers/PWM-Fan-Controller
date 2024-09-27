set shell := ["nu", "-c"]

default: build

alias fmt := format

format: just-fmt rustfmt

rustfmt:
    ^rustfmt **/*.rs

just-fmt:
    ^just --fmt --unstable

alias b := build

build board="attiny85" profile="dev":
    #!/usr/bin/env nu
    cd "boards/{{ board }}"
    ^cargo build --profile "{{ profile }}"
    if {{ board }} == "attiny85" {
        ^cargo objcopy -- -O ihex "pwm-fan-controller-{{ board }}.hex"
    }

alias f := run
alias flash := run
alias r := run

run board="attiny85" profile="dev": (build board profile)
    ^avrdude -c USBtiny -B 4 -p attiny85 -U flash:w:boards/{{ board }}/pwm-fan-controller-{{ board }}.hex:i

alias p := package
alias pack := package

package board="attiny85":
    ^nix build ".#pwm-fan-controller.{{ board }}"

alias u := update
alias up := package

update:
    ^nix flake update
    cd "{{ justfile_directory() }}/boards/attiny85"
    ^cargo update
    cd "{{ justfile_directory() }}/boards/pico"
    ^cargo update
