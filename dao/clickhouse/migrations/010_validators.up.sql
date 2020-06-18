CREATE MATERIALIZED VIEW IF NOT EXISTS validator_blocks_count_mv
  ENGINE = SummingMergeTree()
    PARTITION BY toYYYYMM(day)
    ORDER BY (reg_consensus_address, day) POPULATE AS
select blk_proposer_address reg_consensus_address,
       toStartOfDay(blk_created_at) day,
       max(blk_created_at) last_block_time,
       count()                      blocks
from blocks
group by reg_consensus_address, day;

CREATE VIEW IF NOT EXISTS validator_blocks_day_count_view AS
select reg_consensus_address,
       day,
       max(last_block_time) last_block_time,
       sum(blocks)             blocks
from validator_blocks_count_mv
group by reg_consensus_address, day;

CREATE VIEW IF NOT EXISTS validator_blocks_count_view AS
SELECT reg_consensus_address,
       max(last_block_time) last_block_time,
       sum(blocks) blocks
FROM validator_blocks_count_mv
GROUP BY reg_consensus_address;

CREATE MATERIALIZED VIEW IF NOT EXISTS validator_block_signatures_count_mv
  ENGINE = SummingMergeTree()
    PARTITION BY toYYYYMM(day)
    ORDER BY (reg_consensus_address, day) POPULATE AS
select sig_validator_address reg_consensus_address,
       toStartOfDay(sig_timestamp) day,
       max(sig_timestamp) last_signature_time,
       count()                     signatures
from block_signatures
group by reg_consensus_address, day;

CREATE VIEW IF NOT EXISTS validator_block_signatures_day_count_view AS
select reg_consensus_address,
       day,
       max(last_signature_time) last_signature_time,
       sum(signatures)                     signatures
from validator_block_signatures_count_mv
group by reg_consensus_address, day;

CREATE VIEW IF NOT EXISTS validator_block_signatures_count_view AS
SELECT reg_consensus_address,
       max(last_signature_time) last_signature_time,
       sum(signatures) signatures
FROM validator_block_signatures_count_mv
GROUP BY reg_consensus_address;

DROP TABLE entity_nodes_view;
CREATE VIEW IF NOT EXISTS entity_nodes_view AS
select *
from (
       select *
       from (
              --Group all register txs by entity and node
              select reg_entity_id,
                     reg_id,
                     reg_consensus_address,
                     min(tx_time)        created_time,
                     max(blk_lvl)        blk_lvl,
                     max(reg_expiration) reg_expiration
              from register_node_transactions
              group by reg_entity_id, reg_id, reg_consensus_address
              ) nodes
              ANY
              LEFT JOIN validator_blocks_count_view USING reg_consensus_address
       ) prep
       ANY
       LEFT JOIN validator_block_signatures_count_view USING reg_consensus_address;

CREATE TABLE IF NOT EXISTS public_validators
(
  reg_entity_id FixedString(44),
  pvl_name      String,
  pvl_fee       UInt64,
  pvl_address   String
) ENGINE ReplacingMergeTree()
    PARTITION BY reg_entity_id
    ORDER BY (reg_entity_id);

CREATE VIEW IF NOT EXISTS validator_entity_view AS
select reg_entity_id,
       anyLast(reg_consensus_address) reg_consensus_address,
       max(blk_lvl)         blk_lvl,
       min(created_time)    created_time,
       max(reg_expiration)  reg_expiration,
       max(last_block_time) last_block_time,
       sum(blocks)          blocks,
       sum(signatures)      signatures
from entity_nodes_view
GROUP BY reg_entity_id;


CREATE VIEW IF NOT EXISTS validators_list_view AS
select *
from (
       select *, CASE WHEN reg_expiration >= (select max(blk_epoch) from blocks) THEN 1 ELSE 0 END is_active
       from (SELECT *
             FROM validator_entity_view
                    ANY
                    LEFT JOIN
                  ( select reg_entity_id,
                    min(blk_lvl) start_blk_lvl
                    from register_node_transactions
                    group by reg_entity_id ) val_lvl USING reg_entity_id) validator
              ANY
              LEFT JOIN (SELECT acb_account reg_entity_id, acb_escrow_balance_active, depositors_num
                         from account_last_balance_view ANY
                                LEFT JOIN entity_active_depositors_counter_view USING reg_entity_id
         ) b USING reg_entity_id
       where blocks > 0
          OR signatures > 0
          OR reg_expiration >= (select max(blk_epoch) from blocks)) prep
       ANY
       LEFT JOIN public_validators USING reg_entity_id;

CREATE VIEW IF NOT EXISTS day_max_block_lvl_view AS
select toStartOfDay(blk_created_at) day, max(blk_lvl) blk_lvl
from blocks
group by day;

CREATE VIEW validator_day_stats_view AS
SELECT *
from (select *
      from validator_block_signatures_day_count_view ANY
             LEFT JOIN validator_blocks_day_count_view USING reg_consensus_address, day) pr
       ANY
       LEFT JOIN day_max_block_lvl_view USING day;