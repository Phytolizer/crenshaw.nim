section .data
X	DQ 0
Y	DQ 0
Z	DQ 0
section .text
	global main
main:
	MOV rax,Z
	PUSH rax
	MOV rax,Y
	POP rbx
	CMP rax,rbx
	SETLE al
	MOVZX rax,al
	DEC rax
	MOV QWORD [X],rax
	XOR rax,rax
	RET
