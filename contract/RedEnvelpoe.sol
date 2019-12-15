pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import './SafeMath.sol';
import './Owned.sol';

contract RedEnvelope is Owned {
    using SafeMath for uint256;

    struct _RedEnvelope {
        address master;
        uint256 amount;
        uint256 balance;
        uint8 number;
        uint256 createTime;
    }

    struct _GrabHistory {
        address master;
        uint256 amount;
        uint256 grabTime;
    }

    mapping(bytes32 => _RedEnvelope) internal redEnvelopes;
    mapping(address => _GrabHistory[]) internal grabHistories;

    event Award(address indexed master, uint256 indexed amount, uint8 number);
    event Grab(address indexed participant,bytes32 indexed redId, uint256 amount);

    function() public {
        revert();
    }

    /**
     * @dev 发红包
     *
     * @param _redKey 红包口令
     * @param _number 红包个数
     */
    function award(string _redKey, uint8 _number) public payable returns (bool) {
        require(msg.value > 0, "Not allowed to empty");
        bytes32 id = sha256(abi.encode(_redKey, msg.sender));
        redEnvelopes[id] = _RedEnvelope(msg.sender, msg.value, msg.value, _number, now);
        emit Award(msg.sender, msg.value, _number);
        return true;
    }

    /**
     * @dev 抢红包
     *
     * @param _redKey 红包口令
     * @param _master 红包
     * @param participant 参与者
     */
    function grab(string _redKey,address _master, address participant) public returns (bool){
        bytes32 redId = sha256(abi.encode(_redKey, _master));
       _RedEnvelope memory redEnvelope = redEnvelopes[redId];
        require(redEnvelope.balance > 0, "The red envelope is empty");
        // require(ecrecover(keccak256(abi.encodePacked("\x19MoacNode Signed Message:\n32", redId)),v,r,s) == redEnvelopes[redId].master, "");
        uint256 amount = RandomRatio(redEnvelope);
        participant.transfer(amount);
        redEnvelopes[redId] = redEnvelope;
        grabHistories[participant].push(_GrabHistory(redEnvelope.master, amount, now));
        emit Grab(participant, redId, amount);
        return true;
    }

    /**
     * @dev 随机额度生成
     *
     * @param redEnvelope 红包
     */
    function RandomRatio(_RedEnvelope redEnvelope) private returns (uint256) {
        // todo 随机算法
        uint256 amount = 1 ether;
        redEnvelope.balance = redEnvelope.balance.sub(amount);
        redEnvelope.number = redEnvelope.number - 1;
        return amount;
    }

    /**
     * @dev 未抢空红包剩余金额返还
     *
     * @param _now 执行时间
     */
    function withDraw(uint256 _now) public onlyOwner returns (bool) {

        // todo 考虑基数过大，造成交易失败

        _RedEnvelope redEnvelope;
        if (_now.sub(redEnvelope.createTime) >= 24 hours) {
            redEnvelope.master.transfer(redEnvelope.balance);
        }

        return true;
    }

    /**
     * @dev 未抢空红包剩余金额返还
     *
     * @param participant 参与者
     */
    function HistoricalQuery(address participant) public view returns (_GrabHistory[]) {
        return grabHistories[participant];
    }

}