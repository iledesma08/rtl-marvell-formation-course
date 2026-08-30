// lut_y0.vh — LUT inicial y0(a) para el divisor por Newton-Raphson.
// AUTO-GENERADO por gen_lut.py — NO EDITAR A MANO.
//
// 8 entradas para 'a' normalizado a [0.5, 1.0), formato U(16,15).
// index = (a >> 12) & 7  ->  cada bin tiene ancho 1/16.
//
function automatic logic [15:0] lut_y0(input logic [2:0] idx);
  begin
    case (idx)
      3'd0: lut_y0 = 16'hf0f1;
      3'd1: lut_y0 = 16'hd794;
      3'd2: lut_y0 = 16'hc30c;
      3'd3: lut_y0 = 16'hb216;
      3'd4: lut_y0 = 16'ha3d7;
      3'd5: lut_y0 = 16'h97b4;
      3'd6: lut_y0 = 16'h8d3e;
      3'd7: lut_y0 = 16'h8421;
      default: lut_y0 = 16'h0000;
    endcase
  end
endfunction
