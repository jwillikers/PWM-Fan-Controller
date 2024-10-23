set shell := ["nu", "-c"]

default: build

alias b := build

build profile="dev":
    ^cargo build --profile "{{ profile }}"

alias f := run
alias flash := run
alias r := run

run profile="dev" method="": (build profile)
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
    } else if "{{ method }}" == "wchisp" {
        ^wchisp flash $"target/riscvimac-unknown-none-elf/($build_type)/pwm-fan-controller-qt-py-ch32v203"
    }

alias p := package
alias pack := package

package:
    ^nix build ".#qt-py-ch32v203"

alias u := update
alias up := package

update:
    ^nix flake update
    ^cargo update
