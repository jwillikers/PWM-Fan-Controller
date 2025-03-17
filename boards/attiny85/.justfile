set shell := ["nu", "-c"]

default: build

alias b := build

build profile="dev":
    cargo build
    cargo objcopy -- -O ihex pwm-fan-controller-attiny85.hex

alias f := run
alias flash := run
alias r := run

run profile="dev": (build profile)
    avrdude -c USBtiny -B 4 -p attiny85 -U flash:w:pwm-fan-controller-attiny85.hex:i

# alias p := package
# alias pack := package
# package:
#     ^nix build ".#attiny85"

alias u := update
alias up := update

update:
    nix flake update
    cargo update --verbose
