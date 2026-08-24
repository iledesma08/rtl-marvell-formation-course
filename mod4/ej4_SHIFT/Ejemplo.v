//Ejercicio 5: Array multiplier 8x8, combinacional.
//Version estructural: full adders explicitos (no se usa '+'), para poder
//contar exactamente la cantidad de FA generados.
//
//Estructura: 8 filas de PP (AND) -> 7 filas de CSA (full adders, 3:2,
//no propagan carry entre columnas) -> 1 fila final de RCA (CPA real,
//propaga el carry de punta a punta).

`timescale 1ns/1ps

module arra_mul #(parameter Width_Op1 = 8, Width_Op2 = 8, Width_P = Width_Op1 + Width_Op2)
(
    input  logic [Width_Op1-1:0] a,
    input  logic [Width_Op2-1:0] b,
    output logic [Width_P-1:0]   p
);

    logic [Width_P-1:0] PPs [Width_Op2]; // las 8 filas de productos parciales, ya shifteadas
    logic [Width_P-1:0] S   [Width_Op2]; // S[0]=PPs[0]; S[k] = suma tras la fila CSA k
    logic [Width_P-1:0] C   [Width_Op2]; // C[0]=0;      C[k] = carry (ya corrido) tras la fila CSA k

    genvar gi, gj;

    // ---- Generacion de productos parciales (AND-gates) ----
    generate
        for (gi = 0; gi < Width_Op2; gi = gi + 1) begin : gen_pp
            assign PPs[gi] = (a & {Width_Op1{b[gi]}}) << gi;
        end
    endgenerate

    assign S[0] = PPs[0];
    assign C[0] = '0;

    // ---- 7 filas de full adders (CSA): reducen las 8 filas de PP a un unico par S,C ----
    generate
        for (gi = 1; gi < Width_Op2; gi = gi + 1) begin : gen_csa_row
            logic [Width_P-1:0] raw_carry;

            for (gj = 0; gj < Width_P; gj = gj + 1) begin : gen_csa_col
                full_adder fa (
                    .a    (S[gi-1][gj]),
                    .b    (C[gi-1][gj]),
                    .cin  (PPs[gi][gj]),
                    .sum  (S[gi][gj]),
                    .cout (raw_carry[gj])
                );
            end

            assign C[gi] = raw_carry << 1; // el carry pesa una columna mas
        end
    endgenerate

    // ---- Fila final: RCA real (CPA), propaga el carry de punta a punta ----
    logic [Width_P-1:0] cpa_carry;

    generate
        for (gj = 0; gj < Width_P; gj = gj + 1) begin : gen_cpa
            full_adder fa_cpa (
                .a    (S[Width_Op2-1][gj]),
                .b    (C[Width_Op2-1][gj]),
                .cin  (gj == 0 ? 1'b0 : cpa_carry[gj-1]),
                .sum  (p[gj]),
                .cout (cpa_carry[gj])
            );
        end
    endgenerate

endmodule