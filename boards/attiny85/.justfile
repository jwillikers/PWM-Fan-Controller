default: build

alias fmt := format

format: just-fmt rustfmt

rustfmt:
    cargo fmt

just-fmt:
    just --fmt --unstable

alias b := build

build profile="dev":
    cargo build
    cargo objcopy -- -O ihex attiny85-pwm-fan-controller.hex

alias f := run
alias flash := run
alias r := run

run profile="dev": (build profile)
    avrdude -c USBtiny -B 4 -p attiny85 -U flash:w:attiny85-pwm-fan-controller.hex:i

alias p := package
alias pack := package

package:
    nix build

alias u := update
alias up := package

update:
    nix flake update
    cargo update
