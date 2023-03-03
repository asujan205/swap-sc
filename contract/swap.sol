
// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity >=0.8.2 <0.9.0;
contract TokenSwap is Ownable , ERC721Holder, ERC1155Holder{
    uint256 private _swapIdx;
    uint256 private _ethLocked;
    uint256 private _fee;


    struct NFTs{
        address contractAddr;
        uint256 id;
        uint256 amount; 
    }


  struct Swap {
      address payable owner1;
      NFTs[] anfts;
      uint256 aEth;

      address payable owner2;
      NFTs[] bnfts;
      uint256 bEth; 
      }


      
      mapping(uint256=>Swap) private _swaps;


      event SwapCreated(address indexed Owner1, 
      address indexed Owner2,uint256 indexed id, NFTs[] anfts,uint256 aEth );

      
      
event SwapReady(address indexed owner1,
    address indexed owner2,
    uint256 indexed id,
    NFTs[] aNFTs,
    uint256 aEth,
    NFTs[] bNFTs,
    uint256 bEth);


    event FeeChange(uint256 fee);


    event swapCancel( 
    address indexed owner1,
    address indexed owner2,
    uint256 indexed id
    );
      
      event SwapDone(
    address indexed a,
    address indexed b,
    uint256 indexed id
  );


     modifier onlyA(uint256 swapId) {
    require(_swaps[swapId].owner1 == msg.sender, "onlySwapCreatorCanCall");
    _;
     }
     

  modifier onlyAorB(uint256 swapId) {
    require(
      _swaps[swapId].owner1 == msg.sender ||
      _swaps[swapId].owner2 == msg.sender,
      "onlySwapCreatorCanCall"
    );
    _;
  }

   modifier chargeFee() {
    require(msg.value >= _fee, "feeNotGiven");
    _;
  }


constructor(uint256 fee) {
    _fee = fee;
    super.transferOwnership(msg.sender);
  }

  function getFee() external view returns(uint256) {
    return _fee;
  }

  function changeFee(uint256 fee) external onlyOwner {
    _fee = fee;
    emit FeeChange(_fee);
  }


    function getSwap(uint256 id) external view returns (Swap memory) {
    return _swaps[id];
  }


function CreateSwap(address _baddress ,NFTs[] memory anfts) public payable {
    _swapIdx +=1;
   safeTransfer(msg.sender, address(this), anfts);
 Swap storage swap = _swaps[_swapIdx];

 swap.owner1 = payable(msg.sender);
   for (uint256 i = 0;i < anfts.length; i++) {
      swap.anfts.push(anfts[i]);
    }

    if (msg.value > _fee) {
      swap.aEth = msg.value - _fee;
      _ethLocked += swap.aEth;
    }
swap.owner2 =payable(_baddress);
 emit SwapCreated(msg.sender, swap.owner2, _swapIdx, anfts, swap.aEth);

   

}
//UserB to accept the swap

function IntializeSwap(uint256 id , NFTs[]  memory bNfts) public payable  {

    require(msg.sender == _swaps[id].owner2,"only Owner b initiate" );
    require(_swaps[id].bnfts.length == 0 && _swaps[id].bEth == 0, "swapAlreadyInit");
     safeTransfer(msg.sender, address(this), bNfts);
    _swaps[id].owner2= payable(msg.sender);
    
    for (uint256 i = 0; i < bNfts.length; i++) {
      _swaps[id].bnfts.push(bNfts[i]);
    }

    
    if (msg.value > _fee) {
      _swaps[id].bEth = msg.value - _fee;
      _ethLocked += _swaps[id].bEth;
    }
    emit SwapReady(

        _swaps[id].owner1,
      _swaps[id].owner2,
      id,
      _swaps[id].anfts,
      _swaps[id].aEth,
      _swaps[id].bnfts,
      _swaps[id].bEth
    );



}


function FinishSwap(uint256 id ) public onlyA(id){

  Swap memory swap = _swaps[id];
    require(
      (swap.anfts.length != 0 || swap.aEth != 0) &&
      (swap.bnfts.length != 0 || swap.bEth !=0),
      "uninitSwap"
    );
    _ethLocked -= (swap.aEth + swap.bEth);
    
    //  b-->a
     safeTransfer(address(this), swap.owner1, swap.bnfts);
      if (swap.bEth != 0) {
      swap.owner1.transfer(swap.bEth);
    }
    // a-->b
     safeTransfer(address(this), swap.owner2, swap.anfts);

    if (swap.aEth != 0) {
      swap.owner2.transfer(swap.aEth);
    }

     emit SwapDone(swap.owner1, swap.owner2, id);

    delete _swaps[id];
    

}



  function cancelSwap(uint256 id) external {
    Swap memory swap = _swaps[id];

    require(swap.owner1 == msg.sender || swap.owner2 == msg.sender, "notUserAorB");

    _ethLocked -= (swap.aEth + swap.bEth);

    if (swap.anfts.length != 0) {
      safeTransfer(address(this), swap.owner1, swap.anfts);
    }

    if (swap.aEth != 0) {
      swap.owner1.transfer(swap.aEth);
    }

    if (swap.bnfts.length != 0) {
      safeTransfer(address(this), swap.owner2, swap.bnfts);
    }

    if (swap.bEth != 0) {
      swap.owner2.transfer(swap.bEth);
    }

    emit swapCancel(swap.owner1, swap.owner2, id);

    delete _swaps[id];
  }


 function safeTransfer(address from, address to, NFTs[] memory nfts) internal {
    for (uint256 i = 0; i < nfts.length; i++) {
      // ERC-20 transfer
      if (nfts[i].amount == 0) {
        IERC721(nfts[i].contractAddr).safeTransferFrom(from, to, nfts[i].id, "");
      } else { // ERC-1155 transfer
        IERC1155(nfts[i].contractAddr).safeTransferFrom(from, to, nfts[i].id, nfts[i].amount, "");
      }
    }
  }







}
