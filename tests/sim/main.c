// void putc(char c) {
//     asm volatile (
//         "li t0, 4092\n"
//         "sw %0, 0(t0)\n"
//         :
//         : "r"((unsigned int)(unsigned char)c)
//         : "memory", "t0"
//     );
// }

// void puts(char str[]) {
//     while (*str != '\0') {
//         putc(*(str++));
//     }
// }

// int main(void) {
    
//     return 0;
// }
