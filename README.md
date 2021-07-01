
# OLIMP

**O**pen **L**ibrary for **I**nteger **M**achine **P**rocessing

![OLIMP](https://github.com/cbalint13/OLIMP/blob/main/docs/logo/olimp-logo.png)

OLIMP is a collection of **configurable hardware elements** that operates on **vectors** and ultimately **tensors**.

```
Q: What OLIMP can do ?
A: Hardware for numerical operators.

Q: What OLIMP means for a design ?
A: Designing numerical elements in the vast combinatoric space.

Q: What is the key for any OLIMP operator ?
A: Scheduling is **the key** booth in hardware and software.

Q: What OLIMP can be used to ?
A: Build hardware that computes on any budget, from tiny FPGA to large ASIC.
```

OLIMP use [TVM](https://github.com/apache/tvm) for compute **scheduling** closing the gap between **hardware** and **software** end-to-end design.

-------------------------------------------------------------------------------------

OLIMP targets operators having various precision:

 * **integers** of 2,4,8,16,32 bit length with fixed or mixed precision
 * bitwise ordered **bitplanes** on atomic boolean logic: AND, XOR, POPCNT

--------------------------------------------------------------------------------------

### Demo SoC

  Checkout [Demo SoC](/demo/):

   - OLIMP vector element as RISC-V extension on tiny [icebreaker](https://github.com/icebreaker-fpga/icebreaker).
   - OLIMP elements for dedicated [e-verest](https://github.com/cbalint13/e-verest) usb stick on the budget.

--------------------------------------------------------------------------------------


**ChangeLog**:
   * *01-Jun-2021* early release

**ToDo (WiP)**:
   * finish icebreaker demo
   * publish RTL generators with documentation
   * publish TVM TOPI schedules for each RTL module
   * validate RTL modules via TVM [verilate](https://github.com/apache/tvm/tree/main/src/relay/backend/contrib/verilator) 
   * constrainted end-to-end arhitecture search & optimisation
   * showcase advanced OLIMP blocks on e-verest (ECP5-85k)
