//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.7;

interface IERC721 {
    function transferFrom(
        address _from,
        address _to,
        uint256 _id
    ) external;
}

contract Escrow {
    address public nftAddress;
    address payable public seller;
    address public inspector;
    address public lender;

    // mappings
    mapping(uint256 => bool) public isListed;
    mapping(uint256 => uint256) public purchasePrice;
    mapping(uint256 => uint256) public escrowAmount;
    mapping(uint256 => address) public buyer;
    mapping(uint256 => bool) public inspectionPassed;
    mapping(uint256 => mapping(address => bool)) public approval;

    // create constructor that runs only once
    constructor(
        address _nftAddress,
        address payable _seller,
        address _inspector,
        address _lender
    ) {
        nftAddress = _nftAddress;
        seller = _seller;
        inspector = _inspector;
        lender = _lender;
    }

    // modifiers
    modifier onlySeller() {
        require(msg.sender == seller, "only seller can call this function");
        _;
    }

    modifier onlyBuyer(uint256 _nftID) {
        require(msg.sender == buyer[_nftID], "Only buyer can call this method");
        _;
    }

    modifier onlyInspector() {
        require(msg.sender == inspector, "Only inspector can call this method");
        _;
    }

    // now we need to create a list function
    /// @notice this function will list nfts in our project
    /// @dev remember this functions onlyseller can call it
    function list(
        uint256 _nftID,
        address _buyer,
        uint256 _purchasePrice,
        uint256 _escrowAmount
    ) public payable onlySeller {
        // we need to transfer the nft(real state)
        //from the seller to this contract
        IERC721(nftAddress).transferFrom(msg.sender, address(this), _nftID);

        //now we use our mappings
        isListed[_nftID] = true;
        purchasePrice[_nftID] = _purchasePrice;
        escrowAmount[_nftID] = _escrowAmount;
        buyer[_nftID] = _buyer;
    }

    // put under contract (only buyer - payable escrow)
    function depositEarnest(uint256 _nftID) public payable onlyBuyer(_nftID) {
        require(
            msg.value >= escrowAmount[_nftID],
            "not correct amount sended !"
        );
    }

    // update inspection statues
    function updateInspectionStatus(bool _passed, uint256 _nftID)
        public
        onlyInspector
    {
        inspectionPassed[_nftID] = _passed;
    }

    //approve sale
    function approveSale(uint256 _nftID) public {
        approval[_nftID][msg.sender] = true;
    }

    function finalizeSale(uint256 _nftID) public {
        //Require inspection status
        require(inspectionPassed[_nftID]);
        //Require sale to be authorized
        require(approval[_nftID][buyer[_nftID]]);
        require(approval[_nftID][seller]);
        require(approval[_nftID][lender]);
        //Require funds to be correct amount
        require(address(this).balance >= purchasePrice[_nftID]);

        isListed[_nftID] = false;

        // transfer nft to buyer
        // transferfrom(_from, _to, _tokenId)
        IERC721(nftAddress).transferFrom(address(this), buyer[_nftID], _nftID);

        //transfer funds to seller
        (bool success, ) = payable(seller).call{value: address(this).balance}(
            ""
        );
        require(success);
    }

    // Cancel Sale (handle earnest deposit)
    // -> if inspection status is not approved, then refund, otherwise send to seller
    function cancleSale(uint256 _nftID) public {
        if (inspectionPassed[_nftID] == false) {
            payable(buyer[_nftID]).transfer(address(this).balance);
        } else {
            payable(seller).transfer(address(this).balance);
        }
    }

    receive() external payable {}

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
