// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {StMNT} from "../contracts/Vault.sol";
import {Liquid} from "../contracts/LiqToken.sol";
import {MockWnt} from "../contracts/mockWMNT.sol";
import {Strategy1st} from "../contracts/Strategy1st.sol";

import {ERC20} from "@openzeppelin-contract@5.3.0/contracts/token/ERC20/ERC20.sol";

contract Deploy is Script {
    address public owner = 0x6c64d06ef5C1da66a105893506F6Ecf8C8E191eA;

    function run() external {
        uint256 ownerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(ownerPrivateKey);

        Liquid LIQ = new Liquid(owner);
        MockWnt mockWnt = new MockWnt(owner);
        StMNT stMNT = new StMNT(
            address(0xc0205beC85Cbb7f654c4a35d3d1D2a96a2217436),
            owner,
            owner,
            "stMNT",
            "stMNT",
            owner,
            owner
        );

        mockWnt.mint(owner, 1_000_000 ether);

        address token = address(mockWnt);


        stMNT.setPerformanceFee(0);
        stMNT.setManagementFee(0);
        stMNT.setDepositLimit(1_000_000 ether);

        //Deploy strategy
        Strategy1st strategy1st = new Strategy1st(address(stMNT), owner);
        strategy1st.setLendingPool(0x44949636f778fAD2b139E665aee11a2dc84A2976);
        strategy1st.updateUnlimitedSpending(true);
        strategy1st.updateUnlimitedSpendingInit(true);

        vm.stopBroadcast();
    }
}
