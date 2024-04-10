// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;


contract V1 {
   uint public number;

   function initialValue(uint _num) external {
       number=_num;
   }

   function increase() external {
       number += 1;
   }
}