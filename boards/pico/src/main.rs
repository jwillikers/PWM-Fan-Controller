#![no_std]
#![no_main]

use bsp::entry;
use defmt::*;
use defmt_rtt as _;
use embedded_hal::PwmPin;
use fugit::RateExtU32;
use fugit::Rate;
use panic_probe as _;

use rp_pico as bsp;

use bsp::hal::{
    pac,
    pwm,
    rosc,
    sio::Sio,
};

#[entry]
fn main() -> ! {
    info!("Program start");
    let mut pac = pac::Peripherals::take().unwrap();
    let clock = rosc::RingOscillator::new(pac.ROSC).initialize();
    let sio = Sio::new(pac.SIO);

    let pins = bsp::Pins::new(
        pac.IO_BANK0,
        pac.PADS_BANK0,
        sio.gpio_bank0,
        &mut pac.RESETS,
    );

    let mut pwm_slices = pwm::Slices::new(pac.PWM, &mut pac.RESETS);
    let pwm = &mut pwm_slices.pwm7;
    pwm.set_ph_correct();
    // todo Set the divider such that the frequency will operate at 25 khz?
    // let frequency: Rate<u32, 1, 1_000> = 25.kHz();
    // pwm.set_div_int((clock.operating_frequency() / frequency) as u8);
    // 6_500_000 / 25_000 = 260 which is a bit too big for the u8 type.
    // We'll be stay a bit above 25 kHz, then, but that's fine.
    // pwm.set_div_int(255);
    // pwm.set_div_int(1);
    pwm.enable();

    let channel = &mut pwm.channel_b;
    channel.output_to(pins.gpio15);
    channel.set_duty(channel.get_max_duty() / 5 * 2);

    loop {}
}

// End of file
