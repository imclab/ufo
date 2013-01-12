int forward(long frame, int i) {
  return i;
}

int backward(long frame, int i) {
  return NUM_PIXELS - 1 - i;
}

int peak(long frame, int i) {
  if (i < NUM_PIXELS / 2) {
    return i;
  } else { 
    return NUM_PIXELS - 1 - i;
  }
}

int valley(long frame, int i) {
  if (i < NUM_PIXELS / 2) {
    return NUM_PIXELS / 2 - 1 - i;
  } else { 
    return i;
  }
}

int dither(long frame, int i) {
  if (i % 2 == 0) {
    return NUM_PIXELS - 1 - i;
  } else { 
    return i;
  }
}

int snake(long frame, int i) {
  
  

  // Is this an odd column?
  if (i % (NUM_ROWS*2) >= NUM_ROWS) {

    // // How many odd colums so far?
    // int o = i / (NUM_ROWS*2);

    // // Fake index and real index add up to this number
    // int s = (NUM_ROWS*3-1) + o*(NUM_ROWS*4);

    // return s - i;

    return (NUM_ROWS*3-1) + (i / (NUM_ROWS*2))*(NUM_ROWS*4) - i;

  }

  return i;

}
