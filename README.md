# TBOX-Escrow

This repository contains Solidity smart contracts that provide escrow funcionalities for T-BOX system. The top-level smart contract to use is `RefundEscrow.sol`. See below for the dependencies of the smart contracts in the repository.

## Smart Contract Dependencies
RefundEscrow.sol
<- ConditionalEscrow.sol
   <- Escrow.sol
      <- SafeMath.sol
      <- Secondary.sol
