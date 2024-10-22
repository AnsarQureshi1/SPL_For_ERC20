// SPDX-License-Identifier: UNLICENSED
pragma solidity >0.7.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import { ERC20ForSplMintable } from "../src/erc20_for_spl_mintable.sol";
import { ERC20ForSpl } from "../src/erc20_for_spl.sol";

contract TokenDeploy is Script {

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address account  = vm.addr(deployerPrivateKey);

        console.log("Account",account);
       vm.startBroadcast(deployerPrivateKey);
        ERC20ForSplMintable tk = new ERC20ForSplMintable("DAI", "DAI", 8, account);
        
        
        vm.stopBroadcast();

    }
}

