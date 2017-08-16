module(..., package.seeall)

local counter = require("core.counter")
local shm = require("core.shm")
local schema = require('lib.yang.schema')
local data = require('lib.yang.data')
local state = require('lib.yang.state')
local S = require('syscall')

-- COUNTERS
-- The lwAFTR counters all live in the same directory, and their filenames are
-- built out of ordered field values, separated by dashes.
-- Fields:
-- - "memuse", or direction: "in", "out", "hairpin", "drop";
-- If "direction" is "drop":
--   - reason: reasons for dropping;
-- - protocol+version: "icmpv4", "icmpv6", "ipv4", "ipv6";
-- - size: "bytes", "packets".
counters_dir = "apps/lwaftr/"

function counter_names ()
   local names = {}
   local schema = schema.load_schema_by_name('snabb-softwire-v2')
   for k, node in pairs(schema.body['softwire-state'].body) do
      if node.kind == 'leaf' then
         names[k] = data.normalize_id(k)
      end
   end
   return names
end

function read_counters (pid)
   local s = state.read_state('snabb-softwire-v2', pid or S.getpid())
   local ret = {}
   for k, id in pairs(counter_names()) do
      ret[k] = s.softwire_state[id]
   end
   return ret
end

-- Temporary hack until we migrate all of the lwAFTR's apps to use the
-- SHM frame mechanism.
local managed_counters = {}
for _, app in ipairs({ require('apps.ipv4.reassemble').Reassembler,
                       require('apps.ipv6.reassemble').Reassembler,
                       require('apps.ipv4.fragment').Fragmenter }) do
   for k, v in pairs(app.shm) do managed_counters[k] = true end
end

function init_counters ()
   local counters = {}
   for k, id in pairs(counter_names()) do
      if managed_counters[k] then
         -- Don't create this counter; it's managed by an app.
      else
         counters[k] = {counter}
      end
   end
   return shm.create_frame(counters_dir, counters)
end
