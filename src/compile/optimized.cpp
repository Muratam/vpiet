#include <stdio.h>
#include <stdlib.h>
int *stack;
int maxsize = 10000;
int top = -1;
int next = 0;

void outn_impl(int x) { printf("%d", x); }
int inn_impl() {
  int tmp;
  scanf("%d", &tmp);
  return tmp;
}
int inc_impl() {
  const unsigned char mask[6] = {0x7f, 0x1f, 0x0f, 0x07, 0x03, 0x01};
  unsigned char c = 0;
  scanf("%c", &c);
  int type = 0;  // バイト数タイプ判定(type = byte数 - 1)
  for (; type < 6 && c >= 0xff - mask[type]; type++) {
  }
  // utf-8での対応するマスクをかけてビットシフト
  int result = (c & mask[type]) << type * 6;
  for (int i = 1; i <= type; i++) {
    scanf("%c", &c);
    result += (c & 0x3f) << (6 * (type - i));
  }
  return result;
}
void outc_impl(int x) {
#define MY_DECODE_UTF8(n) \
  for (int i = 1; i <= n; i++) str[i] = 0x80 | ((x >> 6 * (n - i)) & 0x3f);
  unsigned char str[6] = {};
  if (x < 0x80) {
    str[0] = x;
  } else if (x < 0x800) {
    str[0] = 0xd0 | ((x >> 6) & 0x1f);
    MY_DECODE_UTF8(1);
  } else if (x < 0x10000) {
    str[0] = 0xe0 | ((x >> 12) & 0x0f);
    MY_DECODE_UTF8(2);
  } else if (x < 0x200000) {
    str[0] = 0xf0 | ((x >> 18) & 0x07);
    MY_DECODE_UTF8(3);
  } else if (x < 0x4000000) {
    str[0] = 0xfb | ((x >> 24) & 0x03);
    MY_DECODE_UTF8(4);
  } else {
    str[0] = 0xfd | ((x >> 30) & 0x01);
    MY_DECODE_UTF8(5);
  }
  printf("%s", str);
#undef MY_DECODE_UTF8
}

inline void twice() {
  int *new_stack = (int *)malloc(sizeof(int) * maxsize * 2);
  for (int i = 0; i < maxsize; i++) new_stack[i] = stack[i];
  free(stack);
  maxsize *= 2;
}
#define OP2(op)        \
  if (top < 1) return; \
  op;                  \
  top -= 1;
#define TWICE_CHECK() \
  if (top >= maxsize) twice();
#define EMPTY_CHECK() \
  if (top < 0) return;
inline void push(int n) {
  top += 1;
  if (top >= maxsize) twice();
  stack[top] = n;
}
inline void dup() {
  EMPTY_CHECK();
  top += 1;
  TWICE_CHECK();
  stack[top] = stack[top - 1];
}
inline void pop() {
  EMPTY_CHECK();
  top -= 1;
}
inline void not_() {
  EMPTY_CHECK();
  stack[top] = stack[top] == 0;
}
inline void add() { OP2(stack[top - 1] += stack[top]); }
inline void sub() { OP2(stack[top - 1] -= stack[top]); }
inline void mul() { OP2(stack[top - 1] *= stack[top]); }
inline void div_() { OP2(stack[top - 1] /= stack[top]); }
inline void mod() { OP2(stack[top - 1] %= stack[top]); }
inline void greater() { OP2(stack[top - 1] = stack[top - 1] > stack[top]); }
inline void pointer() {
  next = 0;
  EMPTY_CHECK();
  next = (stack[top] + 4) % 4;
  top -= 1;
}
inline void switch_() {
  next = 0;
  EMPTY_CHECK();
  next = (stack[top] + 2) % 2;
  top -= 1;
}
void outn() {
  EMPTY_CHECK();
  outn_impl(stack[top]);
  top -= 1;
}
void outc() {
  EMPTY_CHECK();
  outc_impl(stack[top]);
  top -= 1;
}
void inn() {
  top += 1;
  TWICE_CHECK();
  stack[top] = inn_impl();
}
void inc() {
  top += 1;
  TWICE_CHECK();
  stack[top] = inc_impl();
}

void roll() {
  if (top < 1) return;
  const int a = stack[top];
  top -= 1;
  const int b = top < stack[top] ? top : stack[top];
  top -= 1;
  int *roll_stack = (int *)malloc(sizeof(int) * b);
  for (int i = 0; i < b; i++) {
    roll_stack[i] = stack[top - i];
  }
  for (int i = 0; i < b; i++) {
    stack[top - b + i] = roll_stack[(i - a + b) % b];
  }
  free(roll_stack);
}

inline void start() { stack = (int *)malloc(sizeof(int) * maxsize); }
int terminate() {
  printf("\n");
  free(stack);
  return 0;
}
