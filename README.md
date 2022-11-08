# Fan control balenaBlock

![](./logo.png)
 
This block can be used to controls a cooling fan based on a system thermal zones (temperature measurement managed on Linux systems).

The block supports 2 types of fan control strategies:
- GPIO based ON/OFF control, with an hysteresis,
- PWM based control, with speed slopes.

**NOTE: As linux kernel manages temperatures in Celsius, all temperatures in this block configuration are in Celsius (and integer value).**

## Compatibility

The primary role for this block is to allow for CPU fan control by user-space software, which is easier to re-configure on the fly than kernel based fan control, and thus more suitable for hacking projects.

As long as your senors appear in `/sys/class/thermal/` as a `thermalzone`, and the GPIO/PWM you want to use is not in use by other configuration, this block should be compatible.

## Configuration

The block is configured through environment variables passed to the service. Available variables are:
- For **GPIO mode**:
  - `FAN_GPIO`: The GPIO number your fan is connected to, see your specific board reference to get this number (default value `132`),
  - `THERMAL_HIGH`: The "high" temperature, the fan will turn ON when temperature reaches this level (default value `60`),
  - `THERMAL_LOW`: The "low" temperature, the fan will turn OFF when temperature reaches this level (default value `40`). 

- For **PWM mode**:
  - `PWM`: a comma-separated address of the `PWMCHIP/PWM` to use. _e.g._ `1,0` will use `/sys/class/pwm/pwmchip1/pwm` to control the PWM (no default value, setting this value disables **GPIO mode** and enables **PWM mode**),
  - `PWM_PERIOD`: period to configure your `pwmX/period` to, this will be the maximum value of your duty cycle. (default is `40000`),
  - `PWM_TEMPS`: a comma-separated list of configuration temperature points.These points are used for linear interpolation for the PWM control curve (default `0,40,50,70`).
  - `PWM_DUTY`: a comma-separated list of duty-cycles to apply for each of previously defined temperature points. **This list should be the same length as `PWM_TEMPS`, with each value in the range 0-`PWM_PERIOD`.** (default `0,200,10000,40000`).

- For `both modes`:
  - `REFRESH_DELAY`: the period, in seconds, between two fan speed update (default value `60`),
  - `THERMAL_ZONE`: the thermal zone device number on your system you want to use as a source for fan control (default value `0`).

### Additional configuration

You also will need to set your service as `privileged` and enable `io.balena.features.sysfs=1` in your labels.

## Example configuration in GPIO mode

```yaml
services:
  fan-control:
      image: bh.cr/balena/fan_control_arm
      privileged: true
      restart: always
      labels:
         io.balena.features.sysfs: 1
      environment:
         - 'REFRESH_DELAY=30'
         - 'GPIO="14"'
         - 'THERMAL_ZONE=0'
         - 'THERMAL_LOW=45'
    		 - 'THERMAL_HIGH=65'
```

## Example configuration in PWM mode

```yaml
services:
  fan-control:
      image: bh.cr/balena/fan_control_arm
	    privileged: true
      restart: always
      labels:
         io.balena.features.sysfs: 1
      environment:
	       - 'THERMAL_ZONE=1'
         - 'REFRESH_DELAY=10'
         - 'PWM="1,0"'
         - 'PWM_TEMPS="0,40,50,70"'
         - 'PWM_DUTY="0,100,1000,40000"'
```


