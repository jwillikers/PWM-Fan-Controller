#![no_std]
#![no_main]
#![feature(type_alias_impl_trait)]
#![feature(impl_trait_in_assoc_type)]

// use embedded_hal::pwm::SetDutyCycle;
use hal::time::Hertz;
use hal::timer::low_level::CountingMode;
use hal::timer::simple_pwm::{PwmPin, SimplePwm};
use {ch32_hal as hal, panic_halt as _};

#[qingke_rt::entry]
fn main() -> ! {
    let pac = hal::init(Default::default());

    // SDA on QT Py CH32V203 (PB7)
    let pin = PwmPin::new_ch2::<0>(pac.PB7);

    let mut pwm = SimplePwm::new(
        pac.TIM4,
        None,
        Some(pin),
        None,
        None,
        Hertz::khz(25),
        CountingMode::default(),
    );

    pwm.enable(hal::timer::Channel::Ch2);

    pwm
        // todo Use embedded-hal 1.0 API.
        // .set_duty_cycle(pwm.max_duty_cycle() / 5 * 2)
        .set_duty(hal::timer::Channel::Ch2, pwm.get_max_duty() / 5 * 2);
    // .unwrap();

    loop {}
}
