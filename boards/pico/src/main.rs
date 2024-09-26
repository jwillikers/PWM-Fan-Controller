#![no_std]
#![no_main]

use defmt::*;
use defmt_rtt as _;
use embedded_hal::pwm::SetDutyCycle;
use panic_probe as _;
use rp_pico::entry;
use rp_pico::hal::{pac, pwm, rosc, sio::Sio};

#[entry]
fn main() -> ! {
    info!("Program start");
    let mut pac = pac::Peripherals::take().unwrap();
    let _clock = rosc::RingOscillator::new(pac.ROSC).initialize();
    let sio = Sio::new(pac.SIO);

    let pins = rp_pico::Pins::new(
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
    channel
        .set_duty_cycle(channel.max_duty_cycle() / 5 * 2)
        .unwrap();

    loop {}
}

// End of file
