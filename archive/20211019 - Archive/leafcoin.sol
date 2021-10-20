// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.1;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract Leafcoin is ERC20PresetMinterPauser, Ownable   {
 
   
    constructor () ERC20PresetMinterPauser ("Leafcoin", "LFC") {
        // By construction, there is initially ZERO leafcoins minted
    }
    
   
}