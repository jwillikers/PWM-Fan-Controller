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
    if "{{ board }}" == "attiny85" {
        ^cargo objcopy -- -O ihex "pwm-fan-controller-{{ board }}.hex"
    }

alias f := run
alias flash := run
alias r := run

run board="attiny85" profile="dev" method="": (build board profile)
    #!/usr/bin/env nu
    if "{{ board }}" == "attiny85" {
        ^avrdude -c USBtiny -B 4 -p attiny85 -U flash:w:boards/{{ board }}/pwm-fan-controller-{{ board }}.hex:i
    } else if "{{ board }}" == "pico" {
        let build_type = {
            if "{{ profile }}" == "dev" {
                "debug"
            } else {
                "{{ profile }}"
            }
        }
        if ("{{ method }}" | is-empty) {
            ^cargo run --profile="{{ profile }}"
        } else if "{{ method }}" == "elf2uf2-rs" {
            ^elf2uf2-rs --deploy $"boards/{{ board }}/target/thumbv6m-none-eabi/($build_type)/pwm-fan-controller-pico"
        } else if "{{ method }}" == "probe-rs" {
            ^probe-rs run --chip RP2040 --protocol swd $"boards/{{ board }}/target/thumbv6m-none-eabi/($build_type)/pwm-fan-controller-pico"
        }
    }

alias p := package
alias pack := package

package board="attiny85":
    ^nix build ".#pwm-fan-controller-{{ board }}"

alias u := update
alias up := package

update:
    ^nix flake update
    cd "{{ justfile_directory() }}/boards/attiny85"
    ^cargo update
    cd "{{ justfile_directory() }}/boards/pico"
    ^cargo update

strip-image-metadata:
    #!/usr/bin/env nu
    check-image-metadata --strip
