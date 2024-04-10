// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

contract V2 {
   uint public number;

   function initialValue(uint _num) external {
       number=_num;
   }

   function increase() external {
       number += 1;
   }

   function decrease() external {
       number -= 1;
   }
}