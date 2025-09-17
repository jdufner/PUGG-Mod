#picaxe 14M2

; fuer Debug-Terminalausgaben das Semikolon vor folgender Zeile entfernen:
;#define DEBUG_PRINT sertxd

; fuer Debug-Terminalausgaben das Semikolon vor folgende Zeile setzen:
#define DEBUG_PRINT ;

symbol LED_DATA = B.5 ; bei 14M2
symbol LED_CLK = B.3  ; bei 14M2

symbol NUMBER_OF_LEDS = 60 ; Gesamtanzahl LEDs
symbol NUMBER_OF_LEDS_BYTES = NUMBER_OF_LEDS * 3

symbol LED_DEFAULT_BRIGHTNESS = 0x20 ; Helligkeitsanpassung der LEDs (0xFF = volle Helligkeit)

symbol LED_RAM_START = 28
symbol BPTR_LED_MAX_ADDR = NUMBER_OF_LEDS_BYTES + LED_RAM_START
symbol IR_RAM_START = 300
symbol BPTR_IR_MAX_ADDR = IR_RAM_START + 70

symbol maxLed = NUMBER_OF_LEDS - 1

symbol SSP1CON1_SFR = 0x95
symbol SSP1STAT_SFR = 0x94
symbol SSP1BUF_SFR = 0x91

symbol pinIR = C.0
symbol IR_INT_MASK = %00000001
symbol IR_PULLUP_MASK = 0x0100

symbol multipleLeds = b0
symbol brightness = b1
symbol progNumber = b2
symbol lastProgNumber = b3
symbol color_r = b4
symbol color_g = b5
symbol color_b = b6

symbol localByte1 = b7
symbol localByte2 = b8
symbol localByte3 = b9
#define WheelPos localByte3
symbol localWord1 = w5
symbol localWord2 = w6
symbol localWord3 = w7

symbol counter = b16
symbol state = b17
symbol loopcounter = b18
symbol bptr_end = s_w1
symbol irCounter = b20
symbol bptr_saved = b21
symbol irPulselength = w11
symbol irPulselength_lsb = b22
symbol irPulselength_msb = b23
#define ir_value irPulselength
symbol irData = w12
symbol irData_lsb = b24
symbol irData_msb = b25
symbol irAddr = w13
symbol irAddr_lsb = b26
symbol irAddr_msb = b27

symbol CLOCK_DELAY = 1000*8 ; *8 wegen 32 MHz Takt

; IR-Codes NEC-Fernbedienung CASALUX Remote Control for RGB LED-Flexband 46916
#define IR_BRIGHTER 0
#define IR_DARKER   1
#define IR_OFF      2
#define IR_ON       3
#define IR_RED      4
#define IR_GREEN    5
#define IR_BLUE     6
#define IR_WHITE    7
#define IR_1        8
#define IR_2        9
#define IR_3       10
#define IR_FLASH   11
#define IR_4       12
#define IR_5       13
#define IR_6       14
#define IR_STROBE  15
#define IR_7       16
#define IR_8       17
#define IR_9       18
#define IR_FADE    19
#define IR_10      20
#define IR_11      21
#define IR_12      22
#define IR_SMOOTH  23


#MACRO SetNextLed(r,g,b)
   @bptrinc = b
   @bptrinc = g
   @bptrinc = r
   gosub adjustBrightness
#ENDMACRO


#MACRO SetNextMultipleLeds(quantity,r,g,b)
   multipleLeds = quantity
   for multipleLeds = 1 to quantity
      @bptrinc = b
      @bptrinc = g
      @bptrinc = r
      gosub adjustBrightness
   next multipleLeds
#ENDMACRO


#MACRO SetLed(number,r,g,b) ; number: 0...maxLed
   bptr = number * 3 + LED_RAM_START
   @bptrinc = b;
   @bptrinc = g;
   @bptrinc = r;
   gosub adjustBrightness
#ENDMACRO


#MACRO ClearNextMultipleLeds(quantity)
   multipleLeds = quantity
   for multipleLeds = 1 to quantity
      @bptrinc = 0
      @bptrinc = 0
      @bptrinc = 0
   next multipleLeds
#ENDMACRO


#MACRO SetLedAddress(number) ; number: 0...maxLed
   bptr = number * 3 + LED_RAM_START
#ENDMACRO


#MACRO SetNextMultipleLedsCircular(quantity,r,g,b)
   multipleLeds = quantity
   for multipleLeds = 1 to quantity
      @bptrinc = b
      @bptrinc = g
      @bptrinc = r
      gosub adjustBrightness
      if bptr = BPTR_LED_MAX_ADDR then
         bptr = LED_RAM_START
      endif
   next multipleLeds
#ENDMACRO


#MACRO PrepareLedColor(r,g,b)
   led_r = r
   led_g = g
   led_b = b
#ENDMACRO


#MACRO REPEAT_LEDPROG(prog, x)
   for loopcounter = 1 to x
      gosub prog
      if lastProgNumber <> progNumber then
         gosub changeProg
         return
      endif
   next loopcounter
   gosub changeProg
#ENDMACRO


#MACRO CheckForProgChange
   if lastProgNumber <> progNumber then
      gosub changeProg
      return
   endif
#ENDMACRO

;----------------------------------------------------

setfreq m32

brightness = LED_DEFAULT_BRIGHTNESS
bptr = LED_RAM_START

gosub initSpi
gosub clearLedStripe

progNumber = 0
lastProgNumber = progNumber
state = 0

gosub enable_ir_int

main:
   ;DEBUG_PRINT("Start main",cr,lf)
   DEBUG_PRINT("Programmnummer=",progNumber,cr,lf)
   lastProgNumber = progNumber
   select case progNumber
      case 0
         gosub ledprog_clock
      
      case 1
         gosub ledprog_autoMode
      
      case 2
         gosub ledprog_chain1
      
      case 3
         gosub ledprog_chain2
      
      case 4
         gosub ledprog_chain3

      case 5
         gosub ledprog_chain4

      case 6
         gosub ledprog_chain5

      case 7
         gosub ledprog_chain6

      case 8
         gosub ledprog_brightness
      
      case 9
         gosub ledprog_rainbowCycle
      
      case 10
         gosub ledprog_chain7
      
      case 11
         gosub ledprog_chain8
      
      case 12
         gosub ledprog_chain9
      
      case 255
         progNumber = 9
         
      else
         progNumber = 0
   endselect
   
goto main


adjustBrightness:
   bptr = bptr - 3
   @bptrinc = @bptr * brightness / 0xff
   @bptrinc = @bptr * brightness / 0xff
   @bptrinc = @bptr * brightness / 0xff
return


ledprog_clock:
   for localByte3 = 1 to NUMBER_OF_LEDS
      localByte2 = localByte3 - 1
      localByte1 = localByte3 % 5
      if localByte1 = 0 then
         SetLed(localByte2, 0xFF, 0, 0)
      else
         SetLed(localByte2, 0, 0xFF, 0)
      endif
      gosub updateLeds
      CheckForProgChange
      pause CLOCK_DELAY
   next localByte3

   for localByte3 = 0 to maxLed
      SetLed(localByte3, 0, 0, 0)
      gosub updateLeds
      CheckForProgChange
      pause CLOCK_DELAY
   next localByte3
return


ledprog_autoMode:
   REPEAT_LEDPROG(ledprog_chain1, 6)
   REPEAT_LEDPROG(ledprog_chain2, 6)
   REPEAT_LEDPROG(ledprog_chain3, 6)
   REPEAT_LEDPROG(ledprog_chain4, 6)
   REPEAT_LEDPROG(ledprog_chain5, 6)
   REPEAT_LEDPROG(ledprog_chain6, 6)
   REPEAT_LEDPROG(ledprog_brightness, 6)
   REPEAT_LEDPROG(ledprog_rainbowCycle, 1)
return


ledprog_rainbowCycle:
   for localWord1 = 0 to 255
      for localWord2 = 0 to maxLed
         localWord3 = localWord2 * 256 / NUMBER_OF_LEDS + localWord1
         WheelPos = localWord3 & 255
         
         WheelPos = 255 - WheelPos
         if WheelPos < 85 then
            localByte1 = WheelPos * 3
            localByte2 = 255 - localByte1
            SetNextLed(localByte2, 0, localByte1)
         elseif WheelPos < 170 then
            WheelPos = WheelPos - 85
            localByte1 = WheelPos * 3
            localByte2 = 255 - localByte1
            SetNextLed(0, localByte1, localByte2)
         else
            WheelPos = WheelPos - 170
            localByte1 = WheelPos * 3
            localByte2 = 255 - localByte1
            SetNextLed(localByte1, localByte2, 0)
         endif
      next localWord2
      gosub updateLeds
      CheckForProgChange
      ;pause 1
   next localWord1
return


ledprog_chain1:
   gosub setColors
   for localByte1 = 0 to maxLed
      if localByte1 <> 0 then
         localByte2 = localByte1 - 1
      else
         localByte2 = maxLed
      endif
      SetLed(localByte2, 0, 0, 0)
      SetLed(localByte1, color_r, color_g, color_b)
      gosub updateLeds
      CheckForProgChange
      pause 20
   next localByte1
   state = state + 1
return


ledprog_chain2:
   gosub setColors
   for localByte1 = 0 to maxLed
      SetLed(localByte1, color_r, color_g, color_b)
      gosub updateLeds
      CheckForProgChange
      pause 200
   next localByte1
   state = state + 1
return


ledprog_chain3:
   gosub setColors
   localByte2 = NUMBER_OF_LEDS / 2 - 1
   for localByte1 = 0 to localByte2
      SetLed(localByte1, color_r, color_g, color_b)
      SetLed(NUMBER_OF_LEDS - localByte1 - 1, color_r, color_g, color_b)
      gosub updateLeds
      CheckForProgChange
      pause 400
   next localByte1
   state = state + 1
return


ledprog_chain4:
   gosub setColors
   localByte2 = NUMBER_OF_LEDS / 6 - 1
   for localByte1 = 0 to localByte2
      for localByte3 = localByte1 to maxLed step 10
         SetLed(localByte3, color_r, color_g, color_b)
      next localByte3
      gosub updateLeds
      CheckForProgChange
      pause 400
   next localByte1
   state = state + 1
return


ledprog_chain5:
   gosub setColors
   localByte2 = NUMBER_OF_LEDS / 6 - 1
   for localByte1 = 0 to localByte2
      for localByte3 = localByte1 to maxLed step 10
         if localByte3 <> 0 then
            localByte3 = localByte3 - 1
            SetLed(localByte3, 0, 0, 0)
            localByte3 = localByte3 + 1
         else
            SetLed(maxLed, 0, 0, 0)
         endif
         SetLed(localByte3, color_r, color_g, color_b)
      next localByte3
      gosub updateLeds
      CheckForProgChange
      pause 400
   next localByte1
   state = state + 1
return


ledprog_chain6:
   gosub setColors
   localByte2 = NUMBER_OF_LEDS / 3 - 1
   for localByte1 = 0 to localByte2
      SetLedAddress(localByte1)
      for localByte3 = 1 to 3
         SetNextMultipleLedsCircular(10, color_r, color_g, color_b)
         SetNextMultipleLedsCircular(10, 0, 0, 0)
      next localByte3
      gosub updateLeds
      CheckForProgChange
      pause 300
   next localByte1
   state = state + 1
return


ledprog_chain7:
   gosub setColors2
   for localByte1 = 0 to maxLed
      if localByte1 <> 0 then
         localByte2 = localByte1 - 1
      else
         localByte2 = maxLed
      endif
      SetLed(localByte2, 0, 0, 0)
      SetLed(localByte1, color_r, color_g, color_b)
      gosub updateLeds
      CheckForProgChange
      pause CLOCK_DELAY
   next localByte1
   state = state + 1
return


ledprog_chain8:
   gosub setColors
   for localWord1 = 0 to maxLed
      localWord2 = localWord1 + 1 ; next led
      if localWord2 > maxLed then
         localWord2 = 0
      endif
      for localByte1 = 0 to 7
         localByte2 = localByte1 * 16 ; current brightness step (0, 32, 64, ..., 224)
         localByte3 = 112 - localByte2 ; fading brightness step (224, 192, ..., 0)
         
         ; fade out current LED
         brightness = localByte3
         SetLed(localWord1, color_r, color_g, color_b)
         
         ; fade in next LED
         brightness = localByte2
         SetLed(localWord2, color_r, color_g, color_b)
         
         gosub updateLeds
         brightness = LED_DEFAULT_BRIGHTNESS
         CheckForProgChange
         pause 1000
      next localByte1
   next localWord1
   state = state + 1
return


ledprog_chain9:
   for localByte1 = 0 to maxLed
	gosub setColors2
      if localByte1 <> 0 then
         localByte2 = localByte1 - 1
      else
         localByte2 = maxLed
      endif
      SetLed(localByte2, 0, 0, 0)
      SetLed(localByte1, color_r, color_g, color_b)
	state = state + 1
      gosub updateLeds
      CheckForProgChange
      pause CLOCK_DELAY
   next localByte1
return


ledprog_brightness:
   gosub setColors
   for localByte1 = 0 to 9
      localByte2 = brightness ; save current brightness
      lookup localByte1,(0x08, 0x10, 0x18, 0x20, 0x30, 0x40, 0x60, 0x80, 0xC0, 0xFF),brightness
      brightness = brightness * localByte2 / 0xFF
      SetNextMultipleLeds(NUMBER_OF_LEDS, color_r, color_g, color_b)
      brightness = localByte2 ; restore brightness
      gosub updateLeds
      CheckForProgChange
      pause 1200
   next localByte1
   state = state + 1
return


setColors:
   if state > 5 then
      state = 0
   endif
   lookup state,(0xFF, 0xFF, 0x00, 0x00, 0x00, 0xFF),color_r
   lookup state,(0x00, 0xFF, 0xFF, 0xFF, 0x00, 0x00),color_g
   lookup state,(0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF),color_b
return


setColors2:
   if state > 11 then
      state = 0
   endif
   lookup state,(0xFF, 0xFF, 0xFF, 0x7F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x7F, 0xFF),color_r
   lookup state,(0x00, 0x7F, 0xFF, 0xFF, 0xFF, 0x7F, 0xFF, 0x7F, 0x00, 0x00, 0x00),color_g
   lookup state,(0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF),color_b
return


changeProg:
   state = 0
   bptr = LED_RAM_START
   ClearNextMultipleLeds(NUMBER_OF_LEDS)
   bptr = LED_RAM_START
return


initSpi:
   low LED_CLK ; SCK as output low
   low LED_DATA ; SDO as output low
   pokesfr SSP1CON1_SFR, 0x22 ; SSPEN=1, CKP=0, SSPM=0010 (500kHz)
   pokesfr SSP1STAT_SFR, 0x40 ; SMP=0, CKE=1
return


clearLedStripe:
   bptr = LED_RAM_START
   SetNextMultipleLeds(NUMBER_OF_LEDS, 0, 0, 0)
   gosub updateLeds
return


updateLeds:
   gosub generateStartFrame
   bptr = LED_RAM_START
   for counter = 1 to NUMBER_OF_LEDS
      pokesfr SSP1BUF_SFR,0xFF
      pokesfr SSP1BUF_SFR,@bptrinc
      pokesfr SSP1BUF_SFR,@bptrinc
      pokesfr SSP1BUF_SFR,@bptrinc
   next counter
   gosub generateEndFrame
   bptr = LED_RAM_START
return


generateStartFrame:
   pokesfr SSP1BUF_SFR, 0
   pokesfr SSP1BUF_SFR, 0
   pokesfr SSP1BUF_SFR, 0
   pokesfr SSP1BUF_SFR, 0
return


generateEndFrame:
#rem
the only function of the End frame is to supply more clock pulses to the string until the data has permeated to the last LED. The number of clock pulses required is exactly half the total number of LEDs in the string. The recommended end frame length of 32 is only sufficient for strings up to 64 LEDs.
#endrem
   pokesfr SSP1BUF_SFR, 0xFF
   pokesfr SSP1BUF_SFR, 0xFF
   pokesfr SSP1BUF_SFR, 0xFF
   pokesfr SSP1BUF_SFR, 0xFF
return


enable_ir_int:
   pullup IR_PULLUP_MASK
   SETINT %00000000, IR_INT_MASK
return


interrupt:
   bptr_saved = bptr
   bptr = IR_RAM_START
   do
      PULSIN pinIR, 1, irPulselength
      @bptrinc = irPulselength_lsb
      @bptrinc = irPulselength_msb
   loop while irPulselength <> 0 and bptr < BPTR_IR_MAX_ADDR
   
   DEBUG_PRINT("--------------",cr,lf)
   DEBUG_PRINT("Start. bptr_end=",#bptr,cr,lf)
   bptr_end = bptr
   bptr = IR_RAM_START

   irCounter = 0
   irAddr = 0
   irData = 0

   irPulselength_lsb = @bptrinc
   irPulselength_msb = @bptrinc
   DEBUG_PRINT("Start pulse: ",#irPulselength)
   if irPulselength < 2700 or irPulselength > 4500 then ; 4.5ms => 3600
      DEBUG_PRINT(" failed!", cr,lf)
      goto ir_stop
   endif
   DEBUG_PRINT(cr,lf)

   do while bptr <> bptr_end
      irPulselength_lsb = @bptrinc
      irPulselength_msb = @bptrinc
      DEBUG_PRINT(#irPulselength,cr,lf)
      if irPulselength > 336 and irPulselength < 560 then ; 448 
         ir_value = 0
      elseif irPulselength > 1014 and irPulselength < 1690 then ; 1352
         ir_value = 0x8000
      else
         DEBUG_PRINT("Aborted",cr,lf)
         goto ir_stop
      endif
      if irCounter < 16 then
         irAddr = irAddr / 2 + ir_value
      else
         irData = irData / 2 + ir_value
      endif
      inc irCounter
   loop
ir_stop:
   
   DEBUG_PRINT("Cnt: ", #irCounter)
   if irCounter = 32 then
      DEBUG_PRINT(" OK")
   else
      DEBUG_PRINT(" failed!")
   endif
   DEBUG_PRINT(cr,lf)
   DEBUG_PRINT("Addr: ", #irAddr_msb, " ", #irAddr_lsb,cr,lf)
   DEBUG_PRINT("Data: ", #irData_msb, " ", #irData_lsb,cr,lf)
   
   if irCounter = 32 then
      
      select case irData_lsb
         case IR_DARKER
            progNumber = progNumber + 1
         case IR_BRIGHTER
            progNumber = progNumber - 1
         case IR_OFF
            progNumber = 0
         case IR_ON
            progNumber = 1
         case IR_RED
            progNumber = 2
         case IR_GREEN
            progNumber = 3
         case IR_BLUE
            progNumber = 4
         case IR_WHITE
            progNumber = 5
         case IR_1
            progNumber = 6
         case IR_2
            progNumber = 7
         case IR_3
            progNumber = 8
         case IR_FLASH
            progNumber = 9
         case IR_4
            progNumber = 10
         case IR_5
            progNumber = 11
         case IR_6
            progNumber = 12
      end select
   
   endif

   gosub enable_ir_int
   bptr = bptr_saved
return
