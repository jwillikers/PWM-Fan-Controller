set shell := ["nu", "-c"]

default: build

alias b := build

build profile="dev":
    ^cargo build --profile "{{ profile }}"

alias f := run
alias flash := run
alias r := run

run profile="dev" method="": (build board profile)
    #!/usr/bin/env nu
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
        ^probe-rs --chip RP2040 --protocol swd $"boards/{{ board }}/target/thumbv6m-none-eabi/($build_type)/pwm-fan-controller-pico"
    }

alias p := package
alias pack := package

package:
    ^nix build ".#pwm-fan-controller-pico"

alias u := update
alias up := package

update:
    ^nix flake update
    ^cargo update