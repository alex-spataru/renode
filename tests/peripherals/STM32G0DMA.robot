*** Variables ***
${ISR}                            0x40020000
${IFCR}                             0x40020004
${CCR1}                             0x40020008
${CNDTR1}                           0x4002000C
${CPAR1}                            0x40020010
${CMAR1}                            0x40020014
${CCR2}                             0x4002001C
${CNDTR2}                           0x40020020
${CPAR2}                            0x40020024
${CMAR2}                            0x40020028
${SOURCE}                           0x20000000
${DESTINATION}                      0x20000100

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/stm32g0.repl

Register Should Be
    [Arguments]                     ${address}  ${expected}
    ${value}=  Execute Command      sysbus ReadDoubleWord ${address}
    Should Be Equal As Numbers      ${value}  ${expected}

*** Test Cases ***
Should Keep Channel Enabled After Reading CCR
    Create Machine
    Execute Command                 sysbus WriteDoubleWord ${SOURCE} 0x11223344
    Execute Command                 sysbus WriteDoubleWord ${CPAR1} ${SOURCE}
    Execute Command                 sysbus WriteDoubleWord ${CMAR1} ${DESTINATION}
    Execute Command                 sysbus WriteDoubleWord ${CNDTR1} 4
    # EN | MINC | PSIZE 32 bits | MSIZE 32 bits, peripheral to memory
    Execute Command                 sysbus WriteDoubleWord ${CCR1} 0xA81

    Execute Command                 sysbus.dma1 OnGPIO 1 true
    Register Should Be              ${CNDTR1}  0x3

    # The HAL reads CCR in HAL_DMA_IRQHandler; EN must read back as written and stay set
    Register Should Be              ${CCR1}  0xA81

    Execute Command                 sysbus.dma1 OnGPIO 1 true
    Register Should Be              ${CNDTR1}  0x2
    Register Should Be              0x20000104  0x11223344

Should Start Memory To Memory Transfer Only When EN Is Set
    Create Machine
    Execute Command                 sysbus WriteDoubleWord ${SOURCE} 0x11223344
    Execute Command                 sysbus WriteDoubleWord ${CPAR2} ${SOURCE}
    Execute Command                 sysbus WriteDoubleWord ${CMAR2} ${DESTINATION}
    Execute Command                 sysbus WriteDoubleWord ${CNDTR2} 4
    # EN | PINC | MINC | MEM2MEM, 8-bit items
    Execute Command                 sysbus WriteDoubleWord ${CCR2} 0x40C1

    Register Should Be              ${DESTINATION}  0x11223344
    Register Should Be              ${CNDTR2}  0x0
    Register Should Be              ${ISR}  0x70

    # Clear the channel 2 flags, then rewrite CCR with EN kept set: the transfer must not start again
    Execute Command                 sysbus WriteDoubleWord ${IFCR} 0x10
    Register Should Be              ${ISR}  0x0
    Execute Command                 sysbus WriteDoubleWord ${CCR2} 0x40C3
    Register Should Be              ${CCR2}  0x40C3
    Register Should Be              ${ISR}  0x0

    # Disable, reprogram and enable again: a new transfer starts
    Execute Command                 sysbus WriteDoubleWord ${SOURCE} 0xAABBCCDD
    Execute Command                 sysbus WriteDoubleWord ${CCR2} 0x40C2
    Execute Command                 sysbus WriteDoubleWord ${CPAR2} ${SOURCE}
    Execute Command                 sysbus WriteDoubleWord ${CMAR2} ${DESTINATION}
    Execute Command                 sysbus WriteDoubleWord ${CNDTR2} 4
    Execute Command                 sysbus WriteDoubleWord ${CCR2} 0x40C3
    Register Should Be              ${DESTINATION}  0xAABBCCDD
