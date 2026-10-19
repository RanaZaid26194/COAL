;Q2 - text viewport manager w/ window scroll + live keyword highlighter
;Github Link: github.com/RanaZaid26194/COAL
[ORG 0x100]
JMP start

docLines:   dw 30
nextLine:   dw 0 ;next doc line to show
scrollN:    dw 0
newRow:     dw 0

titleStr:   db ' Text Viewport Manager ', 0
keyword:    db 'window', 0
hint:       db 'Any key = scroll up, ESC = exit', 0
statusBlank: db '                                                  ', 0
statusA:    db 'Total Matches Found: ', 0
statusB:    db ' | Viewport Status: ACTIVE', 0

L00: db 'The lab was almost empty by the time I got the border to draw', 0
L01: db 'properly, just me  and a  guy asleep near  the window.  Every', 0
L02: db 'attempt before  that had  left some  stray character  in  the', 0
L03: db 'corner of the screen, and I kept blaming the loop when it was', 0
L04: db 'really the way  I counted rows.  Once the frame  was fixed  I', 0
L05: db 'moved on to the text itself, which sat in a block of bytes at', 0
L06: db 'the bottom of the file and  had to be copied onto the  screen', 0
L07: db 'one line at a  time. It looked fine  until I tried to  scroll', 0
L08: db 'it, because the  first version shifted  the whole screen  and', 0
L09: db 'dragged the window frame  along with it. So  I rewrote it  to', 0
L10: db 'touch only the  rows inside  the window and  left the  border', 0
L11: db 'alone, which meant  working out  the offset of  every row  by', 0
L12: db 'hand since each  row is  a hundred  and sixty  bytes wide  in', 0
L13: db 'memory. That math took  a full afternoon and  a lot of  scrap', 0
L14: db 'paper. The search was easier than I expected, mostly  because', 0
L15: db 'I stopped trying  to compare  the video  memory directly  and', 0
L16: db 'copied each  row somewhere  flat first.  After that  a  plain', 0
L17: db 'string compare was enough, and changing the colour of a match', 0
L18: db 'only needed the byte next to  the letter, so the text in  the', 0
L19: db 'window never changed. I remember the first time the highlight', 0
L20: db 'showed up on  the right  word, it blinked  at me  for a  good', 0
L21: db 'minute before I believed it.  The last thing was the  counter', 0
L22: db 'at the  bottom, which  I wrote  twice because  the first  one', 0
L23: db 'printed the digits backwards. Pushing them onto the stack and', 0
L24: db 'popping them off again fixed it without any extra tricks.  If', 0
L25: db 'the window ever looks wrong after a change, check the margins', 0
L26: db 'first, then  the row  maths, and  only after  that blame  the', 0
L27: db 'scroll routine. Nine times out of  ten it is the margins  and', 0
L28: db 'nothing else, and the other time it is a missing pop.  Anyway', 0
L29: db 'the window scrolls fine now and I can go home.', 0

docTable: dw L00, L01, L02, L03, L04, L05, L06, L07, L08, L09
          dw L10, L11, L12, L13, L14, L15, L16, L17, L18, L19
          dw L20, L21, L22, L23, L24, L25, L26, L27, L28, L29

start:
	mov ax, 0x0720 ;blank cell, grey on black
	push ax
	call clear_screen

	mov ax, 3 ;top row
	push ax
	mov ax, 8 ;left col
	push ax
	mov ax, 21 ;bottom row
	push ax
	mov ax, 72 ;right col
	push ax
	mov ax, 0x0B ;border color
	push ax
	call draw_window

	mov ax, 4 ;title goes on the row under the border so border stays whole
	push ax
	mov ax, 9 ;center between col 9 ...
	push ax
	mov ax, 71 ;... and col 71
	push ax
	mov ax, titleStr
	push ax
	mov ax, 0x1E ;yellow on blue
	push ax
	call show_title

	;1st page of the doc
	mov ax, [docLines] ;doc shorter than the window? then show only what exists
	cmp ax, 16 ;16 text rows fit in the window
	jbe first_count_ok
	mov ax, 16
first_count_ok:
	mov [nextLine], ax

	mov ax, 5 ;first text row
	push ax
	mov ax, 0 ;start from doc line 0
	push ax
	push word [nextLine] ;how many lines
	mov ax, 10 ;left margin col (8+2)
	push ax
	mov ax, 70 ;right margin col (72-2)
	push ax
	call stream_lines

	mov ah, 2 ;cursor down to the last row
	xor bh, bh
	mov dx, 0x1800
	int 0x10

	sub sp, 2 ;room for the result
	mov ax, 24 ;row 24, last line of screen
	push ax
	mov ax, 8
	push ax
	mov ax, hint
	push ax
	mov ax, 0x07
	push ax
	call print_string
	add sp, 2 ;dont need the result

	;highlight + status right away, no need to wait for a key
	mov ax, keyword
	push ax
	mov ax, 0xCE ;blinking yellow on red
	push ax
	call refresh_view

key_loop:
	mov ah, 0 ;wait 4 a key
	int 0x16
	cmp al, 27 ;esc
	jne key_not_esc
	jmp key_exit
key_not_esc:
	mov ax, [nextLine]
	cmp ax, [docLines]
	jb key_have_lines
	jmp key_exit ;doc is over
key_have_lines:
	mov bx, [docLines] ;how many lines are left to show
	sub bx, ax
	cmp bx, 2 ;scroll 2 lines per key
	jbe key_n_ready
	mov bx, 2 ;only scroll as much as there is left
key_n_ready:
	mov [scrollN], bx

	;scroll just the text part, border stays put
	mov ax, 3
	push ax
	mov ax, 8
	push ax
	mov ax, 21
	push ax
	mov ax, 72
	push ax
	push word [scrollN]
	call scroll_window_up

	mov ax, 21 ;row after the last text row (20), minus n = 1st empty row
	sub ax, [scrollN]
	mov [newRow], ax

	push word [newRow]
	push word [nextLine]
	push word [scrollN]
	mov ax, 10
	push ax
	mov ax, 70
	push ax
	call stream_lines

	mov ax, [scrollN]
	add [nextLine], ax

	mov ax, keyword
	push ax
	mov ax, 0xCE
	push ax
	call refresh_view
	jmp key_loop

key_exit:
	mov ah, 2 ;cursor on last row again so the prompt stays out of the window
	xor bh, bh
	mov dx, 0x1800
	int 0x10

	MOV AX, 0x4C00
	INT 0x21

;refresh_view - highlights the keyword then updates the status bar
;params: keyOffset, attr
;[bp+6]=key [bp+4]=attr
refresh_view:
	push bp
	mov bp, sp
	push ax
	sub sp, 2 ;room for the match count

	mov ax, 3
	push ax
	mov ax, 8
	push ax
	mov ax, 21
	push ax
	mov ax, 72
	push ax
	push word [bp+6]
	push word [bp+4]
	call find_and_highlight
	pop ax ;ax = matches

	push ax
	call show_status

	pop ax
	mov sp, bp
	pop bp
	ret 4

;show_status - row 23: text + number + text
;params: count
;[bp+4]=count
;locals: [bp-2]=col to print at next
show_status:
	push bp
	mov bp, sp
	sub sp, 2
	push ax

	sub sp, 2 ;wipe the old text first
	mov ax, 23
	push ax
	mov ax, 8
	push ax
	mov ax, statusBlank
	push ax
	mov ax, 0x0F
	push ax
	call print_string
	add sp, 2

	sub sp, 2
	mov ax, 23
	push ax
	mov ax, 8
	push ax
	mov ax, statusA
	push ax
	mov ax, 0x0F
	push ax
	call print_string
	pop ax ;col where the text ended
	mov [bp-2], ax

	sub sp, 2
	push word [bp+4]
	mov ax, 23
	push ax
	push word [bp-2]
	mov ax, 0x0F
	push ax
	call printNum
	pop ax ;no. of digits
	add [bp-2], ax

	sub sp, 2
	mov ax, 23
	push ax
	push word [bp-2]
	mov ax, statusB
	push ax
	mov ax, 0x0F
	push ax
	call print_string
	add sp, 2

	pop ax
	mov sp, bp
	pop bp
	ret 2

;clear_screen - param: fill word (char + attr), wipes all 2000 cells
;[bp+4]=fill word
;locals: [bp-2]=cell count
clear_screen:
	push bp
	mov bp, sp
	sub sp, 2
	push ax
	push cx
	push di
	push es
	cld
	mov word [bp-2], 2000
	mov ax, 0xB800
	mov es, ax
	xor di, di
	mov cx, [bp-2]
	mov ax, [bp+4]
	rep stosw
	pop es
	pop di
	pop cx
	pop ax
	mov sp, bp
	pop bp
	ret 2

;draw_window - top, left, bottom, right, attr (pushed in this order)
;[bp+12]=top [bp+10]=left [bp+8]=bottom [bp+6]=right [bp+4]=attr
;locals: [bp-2]=inner width, [bp-4]=row ctr
draw_window:
	push bp
	mov bp, sp
	sub sp, 4
	push ax
	push bx
	push cx
	push dx
	push di
	push es
	cld
	mov ax, 0xB800
	mov es, ax

	mov ax, [bp+6]
	sub ax, [bp+10]
	dec ax ;cols b/w the corners
	mov [bp-2], ax

	;top line
	mov ax, [bp+12] ;di = (row*80+col)*2, same thing everywhere else
	mov dx, 80
	mul dx
	add ax, [bp+10]
	shl ax, 1
	mov di, ax
	mov ah, [bp+4]
	mov al, 0xC9
	stosw
	mov cx, [bp-2]
	mov al, 0xCD
	rep stosw
	mov al, 0xBB
	stosw

	;side bars, 1 row at a time
	mov ax, [bp+12]
	inc ax
	mov [bp-4], ax
draw_window_side:
	mov ax, [bp-4]
	cmp ax, [bp+8]
	jae draw_window_bottom
	mov ax, [bp-4]
	mov dx, 80
	mul dx
	add ax, [bp+10]
	shl ax, 1
	mov di, ax
	mov ah, [bp+4]
	mov al, 0xBA
	stosw
	mov ax, [bp-4]
	mov dx, 80
	mul dx
	add ax, [bp+6]
	shl ax, 1
	mov di, ax
	mov ah, [bp+4]
	mov al, 0xBA
	stosw
	inc word [bp-4]
	jmp draw_window_side

draw_window_bottom:
	mov ax, [bp+8]
	mov dx, 80
	mul dx
	add ax, [bp+10]
	shl ax, 1
	mov di, ax
	mov ah, [bp+4]
	mov al, 0xC8
	stosw
	mov cx, [bp-2]
	mov al, 0xCD
	rep stosw
	mov al, 0xBC
	stosw

	pop es
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	mov sp, bp
	pop bp
	ret 10

;show_title - top, left, right, str offset, attr
;[bp+12]=top [bp+10]=left [bp+8]=right [bp+6]=str [bp+4]=attr
;locals: [bp-2]=title len, [bp-4]=start col
show_title:
	push bp
	mov bp, sp
	sub sp, 4
	push ax
	push cx
	push dx
	push si
	push di
	push es
	cld
	mov ax, 0xB800
	mov es, ax

	mov si, [bp+6] ;count the chars first
	mov word [bp-2], 0
show_title_len:
	lodsb
	or al, al
	jz show_title_got
	inc word [bp-2]
	jmp show_title_len
show_title_got:

	mov ax, [bp+8] ;centre = left + (width - len)/2
	sub ax, [bp+10]
	inc ax
	sub ax, [bp-2]
	shr ax, 1
	add ax, [bp+10]
	mov [bp-4], ax

	mov ax, [bp+12]
	mov dx, 80
	mul dx
	add ax, [bp-4]
	shl ax, 1
	mov di, ax
	mov si, [bp+6]
	mov ah, [bp+4]
	mov cx, [bp-2]
show_title_put:
	lodsb
	stosw
	loop show_title_put

	pop es
	pop di
	pop si
	pop dx
	pop cx
	pop ax
	mov sp, bp
	pop bp
	ret 10

;stream_line - dumps 1 string in video mem, stops at the right margin
;params: row, startCol, endCol, str offset, attr
;[bp+12]=row [bp+10]=startCol [bp+8]=endCol [bp+6]=str [bp+4]=attr
;locals: [bp-2]=max chars that fit
stream_line:
	push bp
	mov bp, sp
	sub sp, 2
	push ax
	push cx
	push dx
	push si
	push di
	push es
	cld
	mov ax, 0xB800
	mov es, ax

	mov ax, [bp+8]
	sub ax, [bp+10]
	inc ax
	mov [bp-2], ax

	mov ax, [bp+12]
	mov dx, 80
	mul dx
	add ax, [bp+10]
	shl ax, 1
	mov di, ax
	mov si, [bp+6]
	mov ah, [bp+4]
	mov cx, [bp-2]
stream_line_next:
	lodsb
	or al, al
	jz stream_line_done
	stosw
	loop stream_line_next
stream_line_done:
	pop es
	pop di
	pop si
	pop dx
	pop cx
	pop ax
	mov sp, bp
	pop bp
	ret 10

;stream_lines - loops stream_line over a bunch of doc lines
;params: startRow, firstIdx, count, startCol, endCol
;[bp+12]=startRow [bp+10]=firstIdx [bp+8]=count [bp+6]=startCol [bp+4]=endCol
;locals: [bp-2]=cur row, [bp-4]=cur idx, [bp-6]=lines left
stream_lines:
	push bp
	mov bp, sp
	sub sp, 6
	push ax
	push bx

	mov ax, [bp+12]
	mov [bp-2], ax
	mov ax, [bp+10]
	mov [bp-4], ax
	mov ax, [bp+8]
	mov [bp-6], ax
stream_lines_again:
	cmp word [bp-6], 0
	je stream_lines_done
	mov bx, [bp-4]
	shl bx, 1 ;its a word table so idx*2
	mov ax, [docTable + bx]
	push word [bp-2]
	push word [bp+6]
	push word [bp+4]
	push ax
	mov ax, 0x07
	push ax
	call stream_line
	inc word [bp-2]
	inc word [bp-4]
	dec word [bp-6]
	jmp stream_lines_again
stream_lines_done:
	pop bx
	pop ax
	mov sp, bp
	pop bp
	ret 10

;print_string - row, col, str offset, attr
;[bp+10]=row [bp+8]=col [bp+6]=str [bp+4]=attr
;locals: [bp-2]=chars printed
;[bp+12]=result slot, gets the col after the last char
print_string:
	push bp
	mov bp, sp
	sub sp, 2
	push ax
	push dx
	push si
	push di
	push es
	cld
	mov ax, 0xB800
	mov es, ax

	mov word [bp-2], 0
	mov ax, [bp+10]
	mov dx, 80
	mul dx
	add ax, [bp+8]
	shl ax, 1
	mov di, ax
	mov si, [bp+6]
	mov ah, [bp+4]
print_string_go:
	lodsb
	or al, al
	jz print_string_fin
	stosw
	inc word [bp-2]
	jmp print_string_go
print_string_fin:
	mov ax, [bp+8]
	add ax, [bp-2]
	mov [bp+12], ax
	pop es
	pop di
	pop si
	pop dx
	pop ax
	mov sp, bp
	pop bp
	ret 8

;printNum - unsigned num, digits go on stack then pop back in the right order
;params: value, row, col, attr
;[bp+10]=value [bp+8]=row [bp+6]=col [bp+4]=attr
;locals: [bp-2]=digit count
;[bp+12]=result slot, gets the no. of digits
printNum:
	push bp
	mov bp, sp
	sub sp, 2
	push ax
	push bx
	push cx
	push dx
	push di
	push es
	cld
	mov ax, 0xB800
	mov es, ax

	mov ax, [bp+10]
	mov bx, 10
	mov word [bp-2], 0
printNum_split:
	xor dx, dx
	div bx
	push dx ;remainder = next digit, comes out backwards
	inc word [bp-2]
	or ax, ax
	jnz printNum_split

	mov ax, [bp+8]
	mov dx, 80
	mul dx
	add ax, [bp+6]
	shl ax, 1
	mov di, ax
	mov ah, [bp+4]
	mov cx, [bp-2]
printNum_show:
	pop dx
	add dl, '0'
	mov al, dl
	stosw
	loop printNum_show

	mov ax, [bp-2]
	mov [bp+12], ax
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	mov sp, bp
	pop bp
	ret 8

;scroll_window_up - pushes the text part of the window up n rows, border + title never touched
;params: top, left, bottom, right, n (the whole window coords, text area is worked out inside)
;[bp+12]=top [bp+10]=left [bp+8]=bottom [bp+6]=right [bp+4]=n
;locals: [bp-2]=width, [bp-4]=rows to move, [bp-6]=row ctr,
;        [bp-8]=height, [bp-10]=n after clamping,
;        [bp-12]=text top, [bp-14]=text left, [bp-16]=text bottom, [bp-18]=text right
scroll_window_up:
	push bp
	mov bp, sp
	sub sp, 18
	push ax
	push bx
	push cx
	push dx
	push si
	push di
	push ds
	push es
	cld

	mov ax, [bp+12] ;shrink the window down to the text area
	add ax, 2
	mov [bp-12], ax
	mov ax, [bp+10]
	add ax, 2
	mov [bp-14], ax
	mov ax, [bp+8]
	sub ax, 1
	mov [bp-16], ax
	mov ax, [bp+6]
	sub ax, 2
	mov [bp-18], ax

	mov ax, [bp-18]
	sub ax, [bp-14]
	inc ax
	mov [bp-2], ax ;width in cells

	mov ax, [bp-16]
	sub ax, [bp-12]
	inc ax
	mov [bp-8], ax ;height in rows

	mov ax, [bp+4]
	cmp ax, [bp-8]
	jbe scroll_window_up_nok
	mov ax, [bp-8] ;n bigger than the window? just clear all of it
scroll_window_up_nok:
	mov [bp-10], ax

	mov ax, [bp-8]
	sub ax, [bp-10]
	mov [bp-4], ax ;rows that stay

	mov ax, 0xB800 ;movsw needs ds n es both on video mem
	mov ds, ax
	mov es, ax

	mov word [bp-6], 0
scroll_window_up_move:
	mov ax, [bp-6]
	cmp ax, [bp-4]
	jae scroll_window_up_blank

	mov bx, [bp-12] ;src row = top + n + i
	add bx, [bp-10]
	add bx, [bp-6]
	mov ax, bx
	mov dx, 80
	mul dx
	add ax, [bp-14]
	shl ax, 1
	mov di, ax
	mov si, di

	mov bx, [bp-12] ;dest row = top + i
	add bx, [bp-6]
	mov ax, bx
	mov dx, 80
	mul dx
	add ax, [bp-14]
	shl ax, 1
	mov di, ax

	mov cx, [bp-2]
	rep movsw ;char n attr move together
	inc word [bp-6]
	jmp scroll_window_up_move

scroll_window_up_blank:
	mov ax, [bp-12] ;empty rows start right after the ones that stayed
	add ax, [bp-4]
	mov [bp-6], ax
scroll_window_up_clr:
	mov ax, [bp-6]
	cmp ax, [bp-16]
	ja scroll_window_up_end
	mov ax, [bp-6]
	mov dx, 80
	mul dx
	add ax, [bp-14]
	shl ax, 1
	mov di, ax
	mov ax, 0x0720
	mov cx, [bp-2]
	rep stosw
	inc word [bp-6]
	jmp scroll_window_up_clr

scroll_window_up_end:
	pop es
	pop ds
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop ax
	mov sp, bp
	pop bp
	ret 10

;find_and_highlight - top, left, bottom, right, key offset, attr
;[bp+14]=top [bp+12]=left [bp+10]=bottom [bp+8]=right [bp+6]=key [bp+4]=attr
;video mem is char,attr,char,attr so cmpsb cant just walk thru it
;so i copy each row into a stack buffer (lodsw/stosb) and run repe cmpsb on that
;if it matches only the attr bytes get changed
;locals: [bp-2]=key len   [bp-4]=match cnt   [bp-6]=cur row
;        [bp-8]=last start   [bp-10]=scan width   [bp-12]=idx in row
;        [bp-14]=video offset of row start   [bp-94 to bp-15]=row buffer (80 bytes, full screen width)
;[bp+16]=result slot, gets the match count
find_and_highlight:
	push bp
	mov bp, sp
	sub sp, 94
	push ax
	push bx
	push cx
	push dx
	push si
	push di
	push ds
	push es
	cld

	mov si, [bp+6] ;key len
	mov word [bp-2], 0
	mov word [bp-4], 0
find_and_highlight_klen:
	lodsb
	or al, al
	jz find_and_highlight_kdone
	inc word [bp-2]
	jmp find_and_highlight_klen
find_and_highlight_kdone:
	cmp word [bp-2], 0
	jne find_and_highlight_haskey
	jmp find_and_highlight_finish ;empty keyword, nothing to search
find_and_highlight_haskey:

	mov ax, [bp+8]
	sub ax, [bp+12]
	sub ax, 3
	mov [bp-10], ax ;cells b/w the side margins
	sub ax, [bp-2]
	mov [bp-8], ax ;last idx a match can start at (can go negative)

	mov ax, [bp+14]
	add ax, 2
	mov [bp-6], ax ;first text row (under border + title)

find_and_highlight_rowloop:
	mov ax, [bp-6]
	cmp ax, [bp+10]
	jb find_and_highlight_rowgo ;still rows left
	jmp find_and_highlight_finish ;jae was too far for short jump so flipped it
find_and_highlight_rowgo:

	mov bx, [bp+12]
	add bx, 2 ;1st text cell after the left margin
	mov ax, [bp-6]
	mov dx, 80
	mul dx
	add ax, bx
	shl ax, 1
	mov di, ax
	mov [bp-14], di
	mov si, di

	mov ax, 0xB800
	mov ds, ax ;ds on video so lodsw can read it
	mov ax, ss
	mov es, ax ;es on the stack buffer
	lea di, [bp-94]
	mov cx, [bp-10]
find_and_highlight_grab:
	lodsw ;al = char, ah = attr
	stosb ;only keep the char
	loop find_and_highlight_grab
	mov ax, ss
	mov ds, ax ;ds back to normal

	mov word [bp-12], 0
find_and_highlight_scan:
	mov ax, [bp-12]
	cmp ax, [bp-8]
	jg find_and_highlight_nextrow

	mov si, [bp+6]
	lea di, [bp-94]
	add di, [bp-12]
	mov cx, [bp-2]
	repe cmpsb ;es is still the stack buffer
	jne find_and_highlight_miss

	inc word [bp-4] ;found one, paint the attr bytes
	mov ax, 0xB800
	mov es, ax
	mov di, [bp-14]
	mov ax, [bp-12]
	shl ax, 1
	add di, ax
	inc di ;+1 so we land on attr
	mov cx, [bp-2]
	mov al, [bp+4]
find_and_highlight_paint:
	stosb
	inc di ;skip the next char byte
	loop find_and_highlight_paint

	mov ax, ss ;es back to buffer for next compare
	mov es, ax
	inc word [bp-12] ;move on by 1 so overlapping matches count too
	jmp find_and_highlight_scan
find_and_highlight_miss:
	inc word [bp-12]
	jmp find_and_highlight_scan

find_and_highlight_nextrow:
	inc word [bp-6]
	jmp find_and_highlight_rowloop

find_and_highlight_finish:
	mov ax, [bp-4]
	mov [bp+16], ax
	pop es
	pop ds
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop ax
	mov sp, bp
	pop bp
	ret 12
