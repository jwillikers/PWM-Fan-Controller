#![no_std]
#![no_main]

use panic_halt as _;

use attiny_hal::entry;
use attiny_hal::simple_pwm::*;

#[entry]
fn main() -> ! {
    let dp = attiny_hal::Peripherals::take().unwrap();
    let pins = attiny_hal::pins!(dp);
    let timer0 = Timer0Pwm::new(dp.TC0, Prescaler::Prescale64);

    // pb0 is pin #5
    let mut pwm_fan = pins.pb0.into_output().into_pwm(&timer0);
    pwm_fan.enable();

    // 40% of 255
    pwm_fan.set_duty(102);

    loop {}
}
