*** Variables ***
${MODER}                            0x50000400
${OTYPER}                           0x50000404
${PUPDR}                            0x5000040C
${IDR}                              0x50000410
${ODR}                              0x50000414
${BSRR}                             0x50000418
${PORT}                             sysbus.gpioPortB
# Pin 12 of port B is not connected to anything in stm32g0.repl
${PIN}                              12
${PIN_MASK}                         0x1000

*** Keywords ***
Create Machine With Pin As Output
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/stm32g0.repl
    # Port B resets to analog mode on every pin; make pin 12 a general-purpose output
    Execute Command                 sysbus WriteDoubleWord ${MODER} 0xFDFFFFFF

Pin Should Read
    [Arguments]                     ${expected}
    ${value}=  Execute Command      sysbus ReadDoubleWord ${IDR}
    Should Be Equal As Numbers      ${value}  ${expected}

*** Test Cases ***
Should Store Output Type
    Create Machine With Pin As Output
    Execute Command                 sysbus WriteDoubleWord ${OTYPER} ${PIN_MASK}
    ${value}=  Execute Command      sysbus ReadDoubleWord ${OTYPER}
    Should Be Equal As Numbers      ${value}  ${PIN_MASK}

Should Drive Push-Pull Output Regardless Of External Level
    Create Machine With Pin As Output
    Execute Command                 sysbus WriteDoubleWord ${ODR} ${PIN_MASK}
    Execute Command                 ${PORT} OnGPIO ${PIN} false
    Pin Should Read                 ${PIN_MASK}

Should Release Open-Drain Output
    Create Machine With Pin As Output
    Execute Command                 sysbus WriteDoubleWord ${OTYPER} ${PIN_MASK}

    # A 0 in the latch drives the pin low
    Execute Command                 sysbus WriteDoubleWord ${ODR} 0x0
    Pin Should Read                 0x0

    # A 1 releases it; with nothing driving the line it reads high (pull-up assumed) ...
    Execute Command                 sysbus WriteDoubleWord ${BSRR} ${PIN_MASK}
    Pin Should Read                 ${PIN_MASK}

    # ... unless the internal pull-down is selected
    Execute Command                 sysbus WriteDoubleWord ${PUPDR} 0x2000000
    Pin Should Read                 0x0

    # Once something drives the line, the released pin follows it
    Execute Command                 ${PORT} OnGPIO ${PIN} true
    Pin Should Read                 ${PIN_MASK}
    Execute Command                 ${PORT} OnGPIO ${PIN} false
    Pin Should Read                 0x0

Should Wire-AND Open-Drain Output With External Level
    Create Machine With Pin As Output
    Execute Command                 sysbus WriteDoubleWord ${OTYPER} ${PIN_MASK}
    Execute Command                 ${PORT} OnGPIO ${PIN} true

    # The port pulls the line low whatever the other side does
    Execute Command                 sysbus WriteDoubleWord ${BSRR} 0x10000000
    Pin Should Read                 0x0

    # Released, the line goes back to the level the other side holds
    Execute Command                 sysbus WriteDoubleWord ${BSRR} ${PIN_MASK}
    Pin Should Read                 ${PIN_MASK}

    # Switching back to push-pull drives the latch again
    Execute Command                 ${PORT} OnGPIO ${PIN} false
    Pin Should Read                 0x0
    Execute Command                 sysbus WriteDoubleWord ${OTYPER} 0x0
    Pin Should Read                 ${PIN_MASK}
