# Matrix Multiplication Hardware Accelerator - Documentation

## Project Overview

This project implements a **3x3 matrix multiplication hardware accelerator** using Verilog HDL with two different approaches:

1. **Dataflow Modeling** - Direct combinational logic implementation
2. **Structural Modeling** - Gate-level implementation using custom arithmetic units

The project targets FPGA or ASIC implementation for System-on-Chip (SoC) applications.

## Architecture

### Matrix Operation
The accelerator computes: **C = A × B** where:
- **A** is a 3×3 matrix of 16-bit signed integers
- **B** is a 3×1 matrix of 16-bit signed integers  
- **C** is a 3×1 result matrix of 32-bit signed integers

Mathematical operation:
```
C[1,1] = A[1,1]*B[1,1] + A[1,2]*B[2,1] + A[1,3]*B[3,1]
C[2,1] = A[2,1]*B[1,1] + A[2,2]*B[2,1] + A[2,3]*B[3,1]
C[3,1] = A[3,1]*B[1,1] + A[3,2]*B[2,1] + A[3,3]*B[3,1]
```

## Module Descriptions

### Core Arithmetic Modules

#### 1. `Half_adder.v`
**Purpose**: Basic half adder building block
**Inputs**: 
- `a`, `b` (1-bit)
**Outputs**: 
- `s` (sum), `c` (carry) (1-bit each)
**Functionality**: Implements XOR for sum, AND for carry

#### 2. `project_1.v` (Full Adder)
**Purpose**: 1-bit full adder using two half adders
**Inputs**: 
- `a`, `b`, `c_in` (1-bit each)
**Outputs**: 
- `s` (sum), `c_out` (carry out) (1-bit each)
**Implementation**: Uses two `Half_adder` instances with OR gate for final carry

#### 3. `signed_adder_subtractor.v`
**Purpose**: 16-bit signed addition/subtraction unit
**Parameters**:
- `BIT_WIDTH` (default: 16)
**Inputs**:
- `a`, `b` (16-bit signed)
- `operation` (1-bit: 0=add, 1=subtract)
**Outputs**:
- `result` (16-bit signed)
- `overflow` (1-bit overflow flag)
**Features**:
- Two's complement subtraction
- Signed overflow detection
- Operation control via single bit

#### 4. `ripple_carry_16bit.v`
**Purpose**: 16-bit structural ripple carry adder/subtractor
**Implementation**: 
- Uses 16 instances of `project_1` (full adder)
- Generate blocks for scalable instantiation
- Structural implementation as requested
**Features**:
- True structural design with discrete components
- Overflow detection for signed arithmetic

#### 5. `signed_multiplier.v`
**Purpose**: 16-bit × 16-bit signed multiplication producing 32-bit result
**Architecture**:
- **Input Processing**: Extracts signs, computes absolute values
- **Unsigned Core**: Shift-and-add algorithm using partial products
- **Output Processing**: Applies correct sign to result
**Sub-modules**:
- `unsigned_multiplier`: Handles unsigned multiplication core
- `ripple_carry_32bit`: 32-bit adder for partial product summation
- `full_adder_1bit`: Basic full adder for 32-bit operations

### Matrix Multiplication Modules

#### 6. `structural_matrix_multiplication.v`
**Purpose**: Complete 3×3 matrix multiplication using structural components
**Implementation**:
- **9 Multipliers**: One for each A[i,j] × B[j,1] operation
- **6 Adders**: Two-stage addition for each result element
- **Fully Structural**: Uses only custom arithmetic modules
**Performance**: Combinational logic, single clock cycle operation
**Resource Usage**: High (9 multipliers, 6 adders)

## Dataflow vs Structural Comparison

| Aspect | Dataflow | Structural |
|--------|----------|------------|
| **Implementation** | Built-in Verilog operators | Custom arithmetic modules |
| **Performance** | Faster synthesis | Slower but educational |
| **Resource Usage** | Optimized by synthesizer | Higher, more predictable |
| **Debugging** | Limited visibility | Full component-level debug |
| **Educational Value** | Low | High - shows gate-level design |

## Testbench Architecture

### 1. `signed_adder_subtractor_tb.v`
- Tests addition and subtraction operations
- Covers positive/negative combinations
- Includes overflow test cases
- Automated pass/fail reporting

### 2. `signed_multiplier_tb.v`  
- Tests all sign combinations
- Includes edge cases (zero, one, maximum values)
- Compares against Verilog built-in multiplication
- Matrix-typical value testing

### 3. `structural_matrix_mult_tb.v`
- Complete matrix multiplication testing
- Multiple test vectors with known results
- Matrix display formatting
- Behavioral model comparison

## Key Design Decisions

### 1. **Signed Arithmetic Handling**
- **Method**: Two's complement representation
- **Multiplication**: Sign extraction → unsigned multiply → sign application
- **Addition**: Direct signed arithmetic with overflow detection

### 2. **16-bit Precision**
- **Input**: 16-bit signed integers (-32,768 to +32,767)
- **Output**: 32-bit signed integers (prevents overflow)
- **Rationale**: Sufficient for typical SoC matrix operations

### 3. **Structural Implementation**
- **Full Adders**: Used `project_1` modules as building blocks
- **Scalability**: Generate blocks for parameterized width
- **Educational**: Shows discrete component assembly

### 4. **Error Handling**
- **Overflow Detection**: Implemented in all arithmetic units
- **Sign Handling**: Robust two's complement operations
- **Edge Cases**: Proper handling of zeros and maximum values

## Performance Characteristics

### Resource Requirements (Structural Implementation)
- **Logic Elements**: ~2000-3000 (FPGA dependent)
- **Multipliers**: 9 × 16-bit signed multipliers
- **Memory**: None (pure combinational)
- **Clock**: Not required (combinational design)

### Timing Characteristics
- **Propagation Delay**: ~50-100ns (depends on FPGA)
- **Critical Path**: Through multiplication and dual addition
- **Throughput**: One result per clock cycle (if clocked)

## Usage Examples

### Basic Instantiation
```verilog
structural_matrix_multiplication #(
    .NBITS(16),
    .RESULT_WIDTH(32)
) matrix_mult (
    .A_11(matrix_a[0][0]), .A_12(matrix_a[0][1]), .A_13(matrix_a[0][2]),
    .A_21(matrix_a[1][0]), .A_22(matrix_a[1][1]), .A_23(matrix_a[1][2]),
    .A_31(matrix_a[2][0]), .A_32(matrix_a[2][1]), .A_33(matrix_a[2][2]),
    .B_11(vector_b[0]), .B_21(vector_b[1]), .B_31(vector_b[2]),
    .C_11(result[0]), .C_21(result[1]), .C_31(result[2])
);
```

### Simulation
```bash
# Compile all modules
vlog *.v

# Run individual tests
vsim signed_adder_subtractor_tb
vsim signed_multiplier_tb  
vsim structural_matrix_mult_tb

# Run matrix test
vsim structural_matrix_mult_tb
run -all
```

## Verification Results

All testbenches demonstrate:
-  Correct arithmetic operations
-  Proper signed number handling
-  Matrix multiplication accuracy
-  Edge case robustness
-  Overflow detection functionality

## Known Limitations

1. **Resource Intensive**: Uses 9 parallel multipliers
2. **Combinational Only**: No pipelined version implemented
3. **Fixed Size**: 3×3 matrix only, not parameterizable
4. **No Clock Domain**: Pure combinational design
5. **Limited Error Reporting**: Overflow flags not exposed at top level

## Future Enhancements

1. **Pipelined Implementation**: Multi-stage for higher frequency
2. **Parameterizable Size**: NxN matrix support
3. **Clock Domain Integration**: Registered inputs/outputs
4. **Error Handling**: Comprehensive overflow/underflow reporting
5. **Power Optimization**: Clock gating, reduced resource usage
6. **Floating Point**: IEEE 754 support for scientific computing

## File Structure
```
Structural Modeling/
├── rtl/
│   ├── Definitions.vh                    # Parameter definitions
│   ├── Half_adder.v                     # Basic half adder
│   ├── project_1.v                      # Full adder
│   ├── signed_adder_subtractor.v        # 16-bit signed add/sub
│   ├── ripple_carry_16bit.v             # Structural 16-bit adder
│   ├── signed_multiplier.v              # 16x16 signed multiplier
│   └── structural_matrix_multiplication.v # Complete matrix mult
└── sim/
    ├── signed_adder_subtractor_tb.v     # Adder/subtractor testbench
    ├── signed_multiplier_tb.v           # Multiplier testbench
    └── structural_matrix_mult_tb.v      # Matrix multiplication testbench
```

## Conclusion

This project successfully demonstrates:
- **Educational Value**: Complete structural implementation from gates up
- **Correctness**: Comprehensive verification of all operations
- **Scalability**: Parameterizable design patterns
- **Real-world Application**: Suitable for SoC matrix acceleration

The structural approach provides deep understanding of digital arithmetic implementation while maintaining functionality equivalent to high-level dataflow models.