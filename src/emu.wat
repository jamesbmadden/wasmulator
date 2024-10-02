;; assumes a ROM is already provided in one of the given memory arrays when the module is instantiated.
;; provides functions to start the emulator, to run a clock cycle, and to set the vertices to be drawn by WebGL.
(module

  ;; import utils from js
  (func $log (import "utils" "log") (param i32))

  ;; import a memory object from js
  ;; for safari support, only a single memory object can be used per module,
  ;; so ROM and RAM are both included.
  ;; ROM is up to 16 pages (1mb), and RAM is 1 page (64kb)
  ;; 16 pages are always reserved fot the ROM, whether or not it needs it all.
  ;; RAM is contained in the first page of memory for easy use, then ROM is the rest.
  (import "mem" "mem" (memory 17))

  ;; also create the cpu registers.
  ;; using i32 since u8 doesn't exist in wasm but interpret as a u8
  ;; allow everything to be accessed from js for debugging
  (global $ra (export "ra") (mut i32) (i32.const 0))
  (global $rb (export "rb") (mut i32) (i32.const 1))
  (global $rc (export "rc") (mut i32) (i32.const 2))
  (global $rd (export "rd") (mut i32) (i32.const 3))
  (global $re (export "re") (mut i32) (i32.const 4))
  ;; note that rf is the flag register (zero, sub, half-carry, carry) in the upper 4 bits. lower all 0
  (global $rf (export "rf") (mut i32) (i32.const 0))
  (global $rh (export "rh") (mut i32) (i32.const 5)) ;; quirk with gb registers, letters change now
  (global $rl (export "rl") (mut i32) (i32.const 6))

  ;; instruction/pointer registers
  (global $pr (export "pr") (mut i32) (i32.const 0))
  (global $ir (export "ir") (mut i32) (i32.const 0))

  ;; gb has "virtual" registors - combinations that create a single u16 register
  ;; again, no u8 in wasm so it's all i32s
  (func $rbc_get (result i32)
    ;; copy current contents of registers b and c to local variables
    (local $bval i32)
    ;; use shift operations then bitwise operations to combine values
    global.get $rb ;; get the value from rb
    ;; shift it by 8
    i32.const 8
    i32.shl
    ;; delete irrelevant bits using AND
    i32.const 65280 ;; 0b0000_0000_0000_0000_1111_1111_0000_0000
    i32.and 
    local.set $bval ;; set it to the local value
    global.get $rc
    ;; delete the irrelevant bits using AND
    i32.const 255 ;; 0b0000_0000_1111_1111
    i32.and ;; no need to store since we use this value in the next operation
    ;; finally, perform an OR on the 2 values to get the resulting combination
    local.get $bval
    i32.or ;; the return value!
  )
  ;; set the virtual rbc register
  (func $rbc_set (param $bc i32)
    ;; get least significant bits of bc for rc
    local.get $bc
    i32.const 255 ;; 0b0000_0000_1111_1111
    i32.and
    global.set $rc
    ;; and the more significant bits for rb, then shift right
    local.get $bc
    i32.const 65280 ;; 0b0000_0000_0000_0000_1111_1111_0000_0000
    i32.and
    i32.const 8
    i32.shr_u
    global.set $rb
  )
  ;; rde virtual register
  (func $rde_get (result i32)
    ;; copy current contents of registers d and e to local variables
    (local $dval i32)
    ;; use shift operations then bitwise operations to combine values
    global.get $rd
    ;; shift it by 8
    i32.const 8
    i32.shl
    ;; delete irrelevant bits using AND
    i32.const 65280 ;; 0b0000_0000_0000_0000_1111_1111_0000_0000
    i32.and 
    local.set $dval ;; set it to the local value
    global.get $re
    ;; delete the irrelevant bits using AND
    i32.const 255 ;; 0b0000_0000_1111_1111
    i32.and ;; no need to store since we use this value in the next operation
    ;; finally, perform an OR on the 2 values to get the resulting combination
    local.get $dval
    i32.or ;; the return value!
  )
  ;; set the virtual rbc register
  (func $rde_set (param $de i32)
    ;; get least significant bits of de for rc
    local.get $de
    i32.const 255 ;; 0b0000_0000_1111_1111
    i32.and
    global.set $re
    ;; and the more significant bits for rb, then shift right
    local.get $de
    i32.const 65280 ;; 0b0000_0000_0000_0000_1111_1111_0000_0000
    i32.and
    i32.const 8
    i32.shr_u
    global.set $rd
  )
  ;; raf virtual register
  (func $raf_get (result i32)
    ;; copy current contents of registers d and e to local variables
    (local $aval i32)
    ;; use shift operations then bitwise operations to combine values
    global.get $ra
    ;; shift it by 8
    i32.const 8
    i32.shl
    ;; delete irrelevant bits using AND
    i32.const 65280 ;; 0b0000_0000_0000_0000_1111_1111_0000_0000
    i32.and 
    local.set $aval ;; set it to the local value
    global.get $rf
    ;; delete the irrelevant bits using AND
    i32.const 255 ;; 0b0000_0000_1111_1111
    i32.and ;; no need to store since we use this value in the next operation
    ;; finally, perform an OR on the 2 values to get the resulting combination
    local.get $aval
    i32.or ;; the return value!
  )
  ;; set the virtual raf register
  (func $raf_set (param $af i32)
    ;; get least significant bits of af for rf
    local.get $af
    i32.const 255 ;; 0b0000_0000_1111_1111
    i32.and
    global.set $rf
    ;; and the more significant bits for ra, then shift right
    local.get $af
    i32.const 65280 ;; 0b0000_0000_0000_0000_1111_1111_0000_0000
    i32.and
    i32.const 8
    i32.shr_u
    global.set $ra
  )
  ;; rhl virtual register
  (func $rhl_get (result i32)
    ;; copy current contents of registers h and l to local variables
    (local $hval i32)
    ;; use shift operations then bitwise operations to combine values
    global.get $rh
    ;; shift it by 8
    i32.const 8
    i32.shl
    ;; delete irrelevant bits using AND
    i32.const 65280 ;; 0b0000_0000_0000_0000_1111_1111_0000_0000
    i32.and 
    local.set $hval ;; set it to the local value
    global.get $rl
    ;; delete the irrelevant bits using AND
    i32.const 255 ;; 0b0000_0000_1111_1111
    i32.and ;; no need to store since we use this value in the next operation
    ;; finally, perform an OR on the 2 values to get the resulting combination
    local.get $hval
    i32.or ;; the return value!
  )
  ;; set the virtual rbc register
  (func $rhl_set (param $hl i32)
    ;; get least significant bits of de for rc
    local.get $hl
    i32.const 255 ;; 0b0000_0000_1111_1111
    i32.and
    global.set $rl
    ;; and the more significant bits for rb, then shift right
    local.get $hl
    i32.const 65280 ;; 0b0000_0000_0000_0000_1111_1111_0000_0000
    i32.and
    i32.const 8
    i32.shr_u
    global.set $rh
  )

  ;; set up memory for emulation
  (func $init (export "init")
    
  )

  ;; load the next operation
  (func $load_op
    ;; load value at PR in memory, then save to IR
    global.get $pr
    i32.load ;; loads from memory at index above
    global.set $ir
    ;; increase pr by 8
    global.get $pr
    i32.const 8
    i32.add
    global.set $pr
  )

  ;; read a register - make it easier to manage instructions by avoiding having to repeat selecting registers each time
  (func $read_reg (param $r i32) (result i32)
    ;; 0 = B, 1 = C, 2 = D, 3 = E, 4 = H, 5 = L, 6 = HL, 7 = A
    local.get $r
    i32.const 0
    i32.eq
    (if
      (then
        global.get $rb
        return
      )
    )
    local.get $r
    i32.const 1
    i32.eq
    (if
      (then
        global.get $rc
        return
      )
    )
    local.get $r
    i32.const 2
    i32.eq
    (if
      (then
        global.get $rd
        return
      )
    )
    local.get $r
    i32.const 3
    i32.eq
    (if
      (then
        global.get $re
        return
      )
    )
    local.get $r
    i32.const 4
    i32.eq
    (if
      (then
        global.get $rh
        return
      )
    )
    local.get $r
    i32.const 5
    i32.eq
    (if
      (then
        global.get $rl
        return
      )
    )
    local.get $r
    i32.const 6
    i32.eq
    (if
      (then
        call $rhl_get
        return
      )
    )
    local.get $r
    i32.const 7
    i32.eq
    (if
      (then
        global.get $ra
        return
      )
    )
    i32.const 0
  )
  ;; write a register - make it easier to manage instructions by avoiding having to repeat selecting registers each time
  (func $write_reg (param $val i32) (param $r i32)

  )
  

  ;; run a CPU cycle
  (func $cycle (export "cycle")
    ;; now the exciting part! get the instruction at PR and then RUN IT!
    ;; define local values for ease of reading instructions
    (local $hnibble i32) ;; the high nibble of the instruction (bits 7-4)
    (local $lnibble i32) ;; the low nibble of the instruction (bits 3-0)

    call $load_op ;; update pr and ir
    global.get $ir ;; get the current instruction
    call $log ;; log the current instruction so we need to get it again lol

    ;; get the nibbles
    global.get $ir
    i32.const 15 ;; 0000 1111
    i32.and ;; select only the lower 4 bits
    local.set $lnibble

    global.get $ir
    i32.const 240 ;; 1111 0000
    i32.and
    i32.const 4 ;; shift right 4 bits
    i32.shr_u
    local.set $hnibble

    ;; the flow of this section - load instruction, check if it's equal to different values.
    global.get $ir
    i32.const 0
    i32.eq
    (if
      (then
        nop ;; nop! do nothing :)
      )
    )

    ;; basic add op has hnibble = 8
    local.get $hnibble
    i32.const 8
    i32.eq
    (if
      (then
        ;; TODO: whether or not to add carry
        local.get $lnibble ;; lnibble contains which reg to read from
        call $read_reg
        global.get $ra ;; add ra with specified register
        i32.add
        global.set $ra ;; write back to ra
        ;; TODO: flags
      )
    )


  )

  ;; write vertices to the graphics memory for use in JS
  (func $gen_vertices (export "gen_vertices")

  )

)