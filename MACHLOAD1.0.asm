;Machine Loader (or Mach Load for short) - A loading program contained in a boot sector
;Scott Kauppinen
;Version 1.0 Started October 8, 2023
;Last edit November 5, 2023 
     
;First version features: 
;*load function reads the first FAT12 file into 07e0:0000
;*preview of binary data after loading
;*error code following the error message if there is a read error
;*auto-loading feature behaves like a boot loader. Runs UI if first entry in root dir is zero in size
;*resume location is passed on the stack when calling loaded programs


;Boot Parameter Block (FAT12 File system defaults):
EntryPoint:	JMP begin	;jump 60 bytes after this instruction to 0000:7C3E
		db 0x00		;unused space from previous instruction
OEM		db 'Qwercitr'
SectSize	dw 0x0200		;512 bytes per sector
ClustSize	db 0x01		;1 sector per cluster (allocation unit = 512 bytes)
ResSect		dw 0x0001		;1 reserved sector (boot sector)
FatCnt		db 0x02		;2 FAT tables
RootEntryLim 	dw 0x00E0		;root directory entry limit for this format is 224 (14 sectors)
TotalSect32	dw 0x0B40		;total # of sectors = 2880
Media		db 0xF0		;medium Descriptor (F0 denotes 3.5", double side, 18-sector track, 80 tracks, 1.44 MB)
FatSize		dw 0x0009		;size of each FAT in sectors (9 is a typical in a DOS image)
TrackSect	dw 0x0012		;18 sectors per track
HeadCnt		dw 0x0002		;2 read-write heads
HiddenSect	dw 0x0000		;0 hidden sectors
Sect32		dw 0x0000		;sectors for over 32 MB
TotalSect	dd 0x00000000;dos formatted has all zeros here dd 0x00000B40	;total sectors in "filesystem" = 2880
BootDrive 	db 0x00		;logical number of boot drive
Reserved	db 0x00		;reserved, empty
BootSign	db 0x29		;extended boot sector signature
VolID		dd 0x12345678	;disk serial number
VolLabel	db 'VolumeLabel'	;volume label
FSType		db 'FAT12   '	;file system type

begin:
	cli  
	jmp 0x07c0:0x0044 ;CS refers to the beginning of the boot sector and the IP is the location within it
	mov ax, 0x07b0	;set up stack at 07b0:00f0 (stack is effectively 240 bytes)  
	mov ss, ax
	mov ax, 0x00f0
	mov bp, ax
	mov sp, ax
	push cs
	pop ds	;can't set ds directly
	sti
    ;auto-load and run on boot if file exists
	;otherwise, machloader runs
	call clrScreen
	call loadFile1
	cmp al, 0xff
	jz main
	jmp run
resume:
    call clrScreen
	call printIntro
	call printMenu
main:
	mov ah, 0x00	;returns BIOS scan code in ah and ASCII code in al
	int 16h     	;keyboard interrupt
	
	cmp ax, 0x011b	;escape key scan code	
	jnz noReboot
	jmp 0xffff:0000	;reboot
noReboot:	
	cmp ax, 0x3B00 ;F1 key (load file)
	jnz noLoad
	call loadFile1
	jmp main
	
noLoad:
	cmp ax, 0x3C00 ;F2 key (run)
	jnz noRun
;to resume, CS needs to be pushed to stack then IP of resume offset
run:
    push cs
    push resume	
    jmp 0x07e0:0000
noRun:	jmp main
	
;loads first file in boot drive root directory. Prints error code or preview of file
loadFile1:
	;load file size (sector starting at disk image offset 0x2600):
	push 0x02	;2 sectors
	push 0x0002	;cylinder 0, sector 20 (where root directory should start in FAT12) 
	mov ah, 0x01
	mov al, BootDrive
	push ax
	call load
	push ax ;save load status
	call clrScreen
	pop ax  ;restore load status
	cmp ah, 0x00
	jnz readError ;if ah != 0x00 then print error and return, else continue
	
    mov ax, [0x023C]	;(read ds:023C)location of size bytes in now loaded in RAM at 07e0:003c (0x7E1C is for short file name entries, windows uses long file name formats)
	cmp ax, 0x0000	;if file size is 0 bytes then print "No File" and return
	jnz notEmpty   	;load actual file if not empty
	mov bx, noFile
	push 0x0007
	push 0x0000
	push cs
	push bx
	call writeVid
	mov al, 0xff    ;return ff to indicate failed auto-load
	ret	
	
readError:
    mov bx, err
    add ah, 0x30
	mov [bx+6], ah	;save error code in error message below
	push 0x0008
	push 0x0000
	push cs
	push bx
	call writeVid
	ret
	

notEmpty:	;manage partial sector and calculate sectors to read based on size:
	dec ax	;if you have a size of 46 00 then you would need to read 45 sectors + 1 (after bit shifting)
	mov cl, 0x09	;shift 9 bits
	shr ax, cl	;divide by 512 to get number of sectors to read
	inc ax	;if you had a size of 46 ff then you would need to read 47 sectors
	push ax

	;read file hard coded at sector starting at image offset 0x4200
	push 0x0010	;first file location is hard coded, cylinder 0, (head 1), sector 16
	mov ah, 0x01 ;head 1
	mov al, BootDrive
	push ax
	call load 
    ;preview loaded memory:
    ;push 0x0008 ;(emu8086 didn't compile these pushes correctly)
    db 0x68
    dw 0x0008 
    ;push 0x0000
    db 0x68
    dw 0x0000
	push cs
	mov bx, succ
	push bx
	call writeVid ;print "Preview:"

	push 0x0730 ;print 1840 non-attributed characters over lines 1 thru 24
	push 0x0100
	push 0x07e0 ;preview file loaded right after boot sector
	push 0x0000
	call writeVid
	call printMenu
	ret
	

;reads specified drive and sectors into 07e0:0000. Returns status code in ah
;stack params (pushed in this order before calling, ends up in register specified below):
;1 number of sectors in al
;2 cylinder in ch and sector in cl
;3 head and drive nibbles in dx
load:
	pop bx	;save caller
	pop dx	;dh=head, dl=drive
	pop cx
	pop ax
	push bx
	mov bx, 0x07E0	;read buffer segment (right after boot sector)
	mov es, bx	
	mov bx, 0x0000	;read buffer offset
	mov ah, 0x02	;read function
	int 13h
	ret

;clears screen but keeps the functions menu bar
clrScreen:
	mov ah, 0x06	;scroll screen function of interrupt 10h
	mov al, 0x00	;0 lines to scroll means clear screen
	mov bx, 0x0000	;page number (unused)
	mov cx, 0x0000	;upper left window coordinates (row,column)
	mov dh, 0x19	;lower right window coordinates (25 by 80 or 19h by 4fh)
	mov dl, 0x4f
	int 10h		;clear screen
	ret
printMenu:	 
	push 0x801B
	push 0x1800 ;line number 24 is 25th line (starting from zero)
	push cs
	push functions
	call writeVid
	ret

;prints program name and version	
printIntro:
	push 0x800e ;print 14 chars with attributes
	push 0x0000
	push cs
	push progName
	call writeVid
	push 0x000b		;11 characters in intro2
	push 0x0100		;print on line 2
	push cs		;message segment (current segment)
	push version	;message offset
	call writeVid
	ret
	
;writes data to text-video memory with/without attributes (ie, color codes)
;stack params (pushed in this order before calling, ends up in register specified below):
;1 signed-magnitude number of characters to display in cx (NEGATIVE number uses attributes, POSITIVE, doesn't)
;2 starting position coordinates in dx (dh=row, dl=column)
;3 segment of visual data in ds
;4 offset of visual data in si
writeVid:
	;manage stack arguments:
	pop ax ;retrieve caller location
	pop si
	pop ds
	pop dx
	pop cx
	push ax ;save caller location   
	;prepare for writing to memory:
	mov ax, 0xB000		;specify video segment
	mov es, ax		;set video segment (for stos instruction)
	mov di, 0x8000		;set video offset directly (1st line)
	;calculate memory address of screen coordinates
	mov ax, 0x00A0  ;multiply by 16 (ax by dh) to get number of bytes to advance by rows in video memory
	mul dh  
	shl dl, 1    ;each column advances two bytes therefore writing 3rd char (position 2) would have value of 4
	mov dh, 0x00
	add di, ax  ;add coordinates to video offset
	;evaluate attribute argument and clear sign bit:   
	shl cx, 1 ;shift negative sign and set CF 
	pushf ;save flags for restoring count magnitude
	shr cx, 1 ;restore count magnitude
	popf
	jo attrib ;SHL with MSB 1 sets overflow flag (use attributes)
plainLoop:
	lodsb  ;put DS:SI into AL
    mov es:di, al
	inc di
	mov es:di, 0x0a ;plain text is phosphor green
	inc di
	loopnz plainLoop
	ret
attrib:
    lodsw
	mov es:di, ax
	add di, 2
	loopnz attrib
	ret

err: DB 'Error   '
succ: DB 'Preview:'
noFile: DB 'No File'
progName: DB 'M',15,'a',10,'c',10,'h',10,'i',10,'n',10,'e',10,' ',10,'L',15,'o',10,'a',10,'d',10,'e',10,'r',10
version: DB 'Version 1.0'
functions: DB 'E',32,'s',32,'c',32,'R',112,'e',112,'b',112,'o',112,'o',112,'t',112,' ',01,'F',32,'1',32,'L',112,'o',112,'a',112,'d',112,'F',112,'i',112,'l',112,'e',112,'1',112,' ',01,'F',32,'2',32,'R',112,'u',112,'n',112
bootSig DW 0xaa55