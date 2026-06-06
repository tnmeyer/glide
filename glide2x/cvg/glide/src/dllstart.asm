; DLL startup code for Tenberry DOS/4G Extender
; Based on Watcom startup code
; Original code was modified by Mantsev Roman

            name     dllstart
.386p
.387

extrn __InitRtns:NEAR
extrn __FiniRtns:NEAR
extrn "C", _Extender:WORD
extrn "C", _psp:WORD
extrn "C", _Envseg:WORD
extrn __hook387:NEAR
extrn __unhook387:NEAR
extrn __8087cw:WORD
extrn __8087:BYTE

BEGTEXT  segment use32 para public 'CODE'
        assume  cs:BEGTEXT
forever label   near
        int     3h
        jmp     short forever
___begtext label byte
        nop     ;3
        nop     ;4
        nop     ;5
        nop     ;6
        nop     ;7
        nop     ;8
        nop     ;9
        nop     ;A
        nop     ;B
        nop     ;C
        nop     ;D
        nop     ;E
        nop     ;F
        public ___begtext
        assume  cs:nothing
BEGTEXT  ends

            assume      nothing
_TEXT       segment  use32 dword public 'CODE'

        public  __GDAptr
        public  __D16Infoseg
        public  __x386_zero_base_selector

; normal execution of the functions below when pulled in from the standard
; math libraries results in the wrong address for __D16Infoseg being accessed
; ergo the replacement code below tailored to be DOS/4G extender specific

; Based on Watcom 10.5 library code


; DLLstart is called automatically by extender, if available, upon load of
; the dll. Function __dll_initialize() is called second.

        public  __DLLstart_
        assume  cs:_TEXT

__DLLstart_ proc
IFDEF DEBUG
   ; Print an ! to the screen to announce that DLL startup code called
   ; For DLL example only
   mov     ah, 2
   mov     dl, '!'
   int     21h
   int     3h
ENDIF
        jmp     short around

;
; copyright message
;
        db      "WATCOM C/C++32 Run-Time system. "
        db      "(c) Copyright by WATCOM International Corp. 1988-1995."
        db      " All rights reserved."
        align   4h
        dd      ___begtext      ; make sure dead code elimination
                                ; doesn't kill BEGTEXT
;
; miscellaneous code-segment messages
;
ConsoleName     db      "con", 00h

around: sti                             ; enable interrupts

   ; for GETDS, must occur before run time init because getds calls are done
   ; during run time init
   mov  ax, ds
   mov  ds:__saved_DS, ax

   ; for kernel data seg addressability. fs is set to the kernel data sel
   ; for the call of DLLstart by the linexe loader
   mov     ds:__D16Infoseg, fs

   ; for runtime library functions ie: malloc
   mov     eax, 06200h
   int     21h                          ; get psp
   mov     ds:_psp, bx
   mov     es, bx
   mov     ax, word ptr es:02Ch         ; env seg in psp
   mov     ds:_Envseg, ax
   mov     _Extender, 1                 ; needs to be set to allow InitRtns to work properly
   mov     eax,000000ffH
   push    ebp
   mov     ebp, 0                       ; __sys_init_387_emulator requires
   call    __InitRtns
   pop     ebp
   mov     eax, 1
   ret
__DLLstart_ endp

__GDAptr                   dd      0    ; IGC and Intel Code Builder GDA address
__D16Infoseg               dw      0    ; DOS/4G kernel segment, loaded dynamicaly
__x386_zero_base_selector  dw      0    ; base 0 selector for X-32VM
L27                        dw      0    ; used for __sys_(f)ini(t)_387_emulator
L28                        db      0    ; used for __sys_(f)ini(t)_387_emulator

db 140h dup(0)
        public  __sys_init_387_emulator
        assume  cs:_TEXT

__sys_init_387_emulator proc near
   push    es
   push    ecx
   push    ebx
   push    edx
   finit
   push    eax
   fstcw   [esp]
   pop     eax
   cmp     ah, 03H
   je      L1
   inc     ebp
L1:
        or      ebp,ebp
   je      L2
   call    L3
L2:
        finit
   fldcw   __8087cw
   fldz
   fldz
   fldz
   fldz
   pop     edx
   pop     ebx
   pop     ecx
   pop     es
   ret

L3:
   mov     byte ptr __8087, 03H
   mov     byte ptr ds:L28, 01H
   smsw    word ptr ds:L27
   and     word ptr ds:L27, 0006H
   sub     esp, 00000008H
   sidt    word ptr [esp]
   mov     ebx, +2H[esp]
   add     ebx, 00000038H
   add     esp, 00000008H
   mov     dx, ds:__D16Infoseg
   sub     eax, eax
   call    __hook387
   ret
__sys_init_387_emulator endp

__exit  proc near
        public  "C",__exit
ifdef __STACK__
        pop     eax                     ; get return code into eax
endif
        jmp     short   ok
        public  __do_exit_with_msg__
; input: ( char *msg, int rc )  always in registers
__do_exit_with_msg__:
        push    edx                     ; save return code
        push    eax                     ; save address of msg
        mov     edx,offset ConsoleName
        mov     eax, 03d01h             ; write-only access to screen
        int     021h
        mov     ebx, eax                ; get file handle
        pop     edx                     ; restore address of msg
        mov     esi, edx                ; get address of msg
        cld                             ; make sure direction forward
L4:     lodsb                           ; get char
        test    al, al                  ; end of string?
        jne     L4                      ; no
        mov     ecx, esi                ; calc length of string
        sub     ecx, edx                ; . . .
        dec     ecx                     ; . . .
        mov     eax, 04000h                ; write out the string
        int     021h                    ; . . .
        pop     eax                     ; restore return code
ok:
        push    eax                     ; save return code
        mov     eax, 00H                ; run all finalizers
        mov     edx, 0FFH               ; run all finalizers
        call    __FiniRtns              ; call finializer routines
        pop     eax                     ; restore return code
        mov     ah, 04cH                ; DOS call to exit with return code
        int     021h                    ; back to DOS
__exit  endp

        public  __GETDS
__GETDS proc    near
        mov   ds, cs:__saved_DS         ; load saved DS value
        ret                             ; return
__saved_DS                 dw      0    ; save area for DS for interrupt routines
__GETDS endp
_TEXT       ends
end         __DLLstart_
