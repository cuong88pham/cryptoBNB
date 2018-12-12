pragma solidity ^0.4.24;

contract Verification {

  /**
   * @dev Recover signer address from a message by using their signature
   * @param hash bytes32 message, the hash is the signed message. What is recovered is the signer address.
   * @param signature bytes signature, the signature is generated using web3.eth.sign()
   */
  function recover(bytes32 hash, bytes signature)
    public
    pure
    returns (address)
  {
    bytes32 r;
    bytes32 s;
    uint8 v;

    // Check the signature length
    if (signature.length != 65) {
      return (address(0));
    }

    // Divide the signature in r, s and v variables
    // ecrecover takes the signature parameters, and the only way to get them
    // currently is to use assembly.
    // solium-disable-next-line security/no-inline-assembly
    assembly {
      r := mload(add(signature, 0x20))
      s := mload(add(signature, 0x40))
      v := byte(0, mload(add(signature, 0x60)))
    }

    // Version of signature should be 27 or 28, but 0 and 1 are also possible versions
    if (v < 27) {
      v += 27;
    }

    // If the version is correct return the signer address
    if (v != 27 && v != 28) {
      return (address(0));
    } else {
      // solium-disable-next-line arg-overflow
      return ecrecover(hash, v, r, s);
    }
  }
}

contract PropertyBase{
  address public Signer; 
  uint public PropertyValue;
  bytes32 public licenseHouse;
  address owner;
  address renter;
  uint public balanceToDistribute;
  uint public onwerBalance;


  uint currentRentStartTime = 0;
  uint currentRentEndTime = 0;

  event RentProperty(address indexed _renter ,uint _rentValue, uint _rentalStart,uint _rentalEnd);
  event CheckoutDaily(address indexed _renter,uint _rentalEnd, bool _endedWithinPeriod);
  event TransferEthToContract(address _signer,uint _amount, uint indexed _eventDate);

  uint constant RATE_DAILYRENTAL = 1 ether;
  uint constant RATE_MONTHRENTAL = 20 ether;

  bool PropertyIsReady = false;
  modifier onlyIfReady {
    require(PropertyIsReady);
    _;
  }
  
  enum PropertyEntity {
    None,
    Owner,
    DailyRental,
    MonthyRental
  }

  enum PropertyStatus {
    Idle,
    Rent,
    Sold,
    Unavailable
  }
  PropertyEntity currentPropertyEntity;
  PropertyStatus currentPropertyStatus;

  function constructor(bytes32 _licenseHouse, uint _propertyValue) public{
    require(_licenseHouse.length >0 && _propertyValue > 0);
    licenseHouse = _licenseHouse;
    Signer = msg.sender;
    currentPropertyEntity = PropertyEntity.None;
    currentPropertyStatus = PropertyStatus.Idle;
  }
  
  function setOwner(address _owner) public {
    require(msg.sender == Signer);
    owner = _owner;
    PropertyIsReady = true;
  }

  function rentProperty() public onlyIfReady payable{
    require (currentPropertyStatus == PropertyStatus.Idle);
    require (msg.value == RATE_DAILYRENTAL);
    renter = msg.sender;
    currentPropertyStatus = PropertyStatus.Rent;
    currentRentStartTime = now;
    currentPropertyEntity = PropertyEntity.DailyRental;
    currentRentEndTime = now + 1 days;
    balanceToDistribute += msg.value;
    emit RentProperty(renter, msg.value, currentRentStartTime, currentRentEndTime);
  }

  function Checkout () public onlyIfReady {
    
    require ((msg.sender == Signer && now > currentRentEndTime)
            || msg.sender == renter);

    require (currentPropertyStatus == PropertyStatus.Rent);
    require (currentPropertyEntity == PropertyEntity.DailyRental);
    bool endedWithinPeriod = now <= currentRentEndTime;
    emit CheckoutDaily(renter, now, endedWithinPeriod);

    renter = address(0);
    currentPropertyStatus = PropertyStatus.Idle;
    currentPropertyEntity = PropertyEntity.None;
    currentRentStartTime = 0;
    currentRentEndTime = 0;
    distributeEarnings();
  }
  
  function distributeEarnings() internal onlyIfReady {
    transferEthToContract();
    onwerBalance += balanceToDistribute;
  }

  function transferEthToContract() internal onlyIfReady {
    // WIE 
    uint amount = 1 * (10 ** 17); 
    require (Signer.balance < amount);
    require(balanceToDistribute >= amount);
    balanceToDistribute -= amount; 
    Signer.transfer(amount);
    emit TransferEthToContract(Signer, amount, now);
  }

}
