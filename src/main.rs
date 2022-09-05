#![no_std]
#![no_main]

use cortex_m_rt::entry;
use embedded_hal::digital::v2::OutputPin;
use embedded_hal::PwmPin;
use embedded_time::rate::*;
use panic_halt as _;

use adafruit_qt_py_rp2040::{
    hal::{
        // clocks::{
        //     ClockManager,
        // },
        pac,
        rosc,
        Sio,
    },
    Pins,
};

#[entry]
fn main() -> ! {
    let mut pac = pac::Peripherals::take().unwrap();

    let clock = rosc::RingOscillator::new(pac.ROSC).initialize();
    // let clocks = ClockManager::new(pac.CLOCKS);
    // clocks.system_clock.configure_clock().map_err(InitError::ClockError)?;

    let sio = Sio::new(pac.SIO);

    let pins = Pins::new(
        pac.IO_BANK0,
        pac.PADS_BANK0,
        sio.gpio_bank0,
        &mut pac.RESETS,
    );

    pins.neopixel_power.into_push_pull_output().set_low().unwrap();

    let mut pwm_slices = adafruit_qt_py_rp2040::hal::pwm::Slices::new(pac.PWM, &mut pac.RESETS);
    let pwm = &mut pwm_slices.pwm6;
    pwm.set_ph_correct();
    // Set the divider such that the frequency will operate at 25 khz.
    pwm.set_div_int((clock.operating_frequency() / 25.kHz().integer()).integer() as u8);
    pwm.enable();

    let channel = &mut pwm.channel_b;
    channel.output_to(pins.a0);
    channel.set_duty(channel.get_max_duty() * 2 / 5);

    loop {}
}
