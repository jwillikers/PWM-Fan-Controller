set shell := ["nu", "-c"]

default: build

alias c := check

check: && format
    #!/usr/bin/env nu
    ^yamllint .
    ^asciidoctor '**/*.adoc'
    ^lychee --cache **/*.html LICENSE-*
    ^nix flake check

alias b := build

build board="attiny85" profile="dev":
    #!/usr/bin/env nu
    cd "boards/{{ board }}"
    ^cargo build --profile "{{ profile }}"
    if "{{ board }}" == "attiny85" {
        ^cargo objcopy -- -O ihex "pwm-fan-controller-{{ board }}.hex"
    }

alias fmt := format

format:
    treefmt

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
            ^probe-rs run \
                --chip RP2040 \
                --protocol swd \
                $"boards/{{ board }}/target/thumbv6m-none-eabi/($build_type)/pwm-fan-controller-pico"
        }
    } else if "{{ board }}" == "qt-py-ch32v203" {
        let build_type = {
            if "{{ profile }}" == "dev" {
                "debug"
            } else {
                "{{ profile }}"
            }
        }
        ^wchisp flash \
            $"boards/{{ board }}target/riscvimac-unknown-none-elf/($build_type)/pwm-fan-controller-qt-py-ch32v203"
    }

alias p := package
alias pack := package

package board="attiny85":
    nix build ".#{{ board }}"

alias u := update
alias up := update

update:
    nix run ".#update-nix-direnv"
    nix run ".#update-nixos-release"
    nix flake update
    cd "{{ justfile_directory() }}/boards/attiny85"
    cargo update
    cd "{{ justfile_directory() }}/boards/pico"
    cargo update
    cd "{{ justfile_directory() }}/boards/qt-py-ch32v203"
    cargo update
