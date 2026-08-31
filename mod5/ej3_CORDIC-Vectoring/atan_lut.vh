// atan_lut.vh — tabla atan(2^-i) en S(16,14), unidades de pi.
// Generado por gen_roms.py. No editar.
case (index)
  4'd0 : value = 16'sd4096  ; // atan(2^- 0)/pi * 2^14
  4'd1 : value = 16'sd2418  ; // atan(2^- 1)/pi * 2^14
  4'd2 : value = 16'sd1278  ; // atan(2^- 2)/pi * 2^14
  4'd3 : value = 16'sd649   ; // atan(2^- 3)/pi * 2^14
  4'd4 : value = 16'sd326   ; // atan(2^- 4)/pi * 2^14
  4'd5 : value = 16'sd163   ; // atan(2^- 5)/pi * 2^14
  4'd6 : value = 16'sd81    ; // atan(2^- 6)/pi * 2^14
  4'd7 : value = 16'sd41    ; // atan(2^- 7)/pi * 2^14
  4'd8 : value = 16'sd20    ; // atan(2^- 8)/pi * 2^14
  4'd9 : value = 16'sd10    ; // atan(2^- 9)/pi * 2^14
  4'd10: value = 16'sd5     ; // atan(2^-10)/pi * 2^14
  4'd11: value = 16'sd3     ; // atan(2^-11)/pi * 2^14
  4'd12: value = 16'sd1     ; // atan(2^-12)/pi * 2^14
  4'd13: value = 16'sd1     ; // atan(2^-13)/pi * 2^14
  4'd14: value = 16'sd0     ; // atan(2^-14)/pi * 2^14
  4'd15: value = 16'sd0     ; // atan(2^-15)/pi * 2^14
  default: value = 16'sd0;
endcase
