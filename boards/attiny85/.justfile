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

alias u := update
alias up := package

update:
    nix flake update
    cargo update
