import stdimport
proc `*`*(str: string, n: int): string =
  result = ""
  for i in 0..<n: result &= str
proc fscanf*(c: File, frmt: cstring) {.varargs, importc, header: "<stdio.h>".}
