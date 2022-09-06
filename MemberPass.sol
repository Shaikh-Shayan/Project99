// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts@4.7.3/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts@4.7.3/access/Ownable.sol";
import "@openzeppelin/contracts@4.7.3/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts@4.7.3/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts@4.7.3/utils/cryptography/ECDSA.sol";


contract MemberPass is ERC1155, Ownable, ERC1155Burnable, EIP712 {
    string private constant SIGNING_DOMAIN = "Voucher-Domain";
    string private constant SIGNING_VERSION = "1";
    uint256 immutable MAX_SUPPLY;
    uint256 minted = 0;
    uint256 creationTime;
    uint256 burnTime;
    mapping(uint256 => bool) redeemed;
    address private minter;

    struct NFTVoucher {
        uint256 tokenId;
        uint256 minPrice;
        string uri;
        address buyer;
        bytes signature;
    }

    constructor(address signer, uint256 maxSupply) ERC1155("MemberPass") EIP712(SIGNING_DOMAIN, SIGNING_VERSION) {
        minter = signer;
        creationTime = block.timestamp;
        burnTime = creationTime + 31536000;
        MAX_SUPPLY = maxSupply;
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function redeem(NFTVoucher calldata voucher)
        public
        payable
    {   
        require(minter == _verify(voucher), "Invalid signer");
        require(redeemed[voucher.tokenId] != true, "Already redeemed!");
        require(voucher.tokenId == 1, "Token doesn't exist");
        require(minted+1< MAX_SUPPLY, "Not enough supply");
        require(msg.value >= voucher.minPrice, "Not enough ethers sent");

        _mint(voucher.buyer, voucher.tokenId, 1, "");

        minted += 1;
        redeemed[voucher.tokenId] = true;
    }
    
    //function mint(address account, uint256 id)
    //  public
    //   payable
    //{   
    //    require(id==1, "Token doesn't exists");
    //    require(minted+1 <= MAX_SUPPLY, "Not enough supply");
    //    require(msg.value >= 1 ether, "Not enough amount sent to buy NFT");
    //    _mint(account, id, 1, "");
    //    minted += 1;
    //}

    function burn(
        address account,
        uint256 id,
        uint256 value
    ) public override {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );

        require(block.timestamp > burnTime, "You are not allowed to burn the nft before 1 year");
        super.burn(account, id, value);
    }

    function withdraw() public onlyOwner{
        require(address(this).balance >0, "Balance is 0");
        payable(owner()).transfer(address(this).balance);
    }

     function _verify(NFTVoucher calldata voucher) internal view returns (address) {
        bytes32 digest = _hash(voucher);
        return ECDSA.recover(digest, voucher.signature);
    }

    function _hash(NFTVoucher calldata voucher) internal view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(
            keccak256("NFTVoucher(uint256 tokenId,uint256 minPrice,string uri,address buyer)"),
            voucher.tokenId,
            voucher.minPrice,
            keccak256(bytes(voucher.uri)),
            voucher.buyer
        )));
    }

}
