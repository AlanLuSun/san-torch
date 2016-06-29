require 'nngraph'
require 'nn'
require 'misc.maskSoftmax'
local attention = {}

function attention.stack_atten(input_size, att_size, batch_size, img_seq_size, output_size, drop_ratio)
			       -- d            k	100              196	       1000         0.5
    local inputs = {}
    local outputs = {}
    table.insert(inputs, nn.Identity()()) 
    table.insert(inputs, nn.Identity()()) 

    local ques_feat = inputs[1]	-- [batch_size, d]
    local img_feat = inputs[2]	-- [batch_size, m, d]

    -- Stack 1
    local ques_emb_1 = nn.Linear(input_size, att_size)(ques_feat)   -- [batch_size, att_size]
    local ques_emb_expand_1 = nn.Replicate(img_seq_size,2)(ques_emb_1)         -- [batch_size, m, att_size]
    local img_emb_dim_1 = nn.Linear(input_size, att_size, false)(nn.View(-1,input_size)(img_feat)) -- [batch_size*m, att_size]
    local img_emb_1 = nn.View(-1, img_seq_size, att_size)(img_emb_dim_1)        		          -- [batch_size, m, att_size]
    -- drop out or not, comment code if u need
    local h1 = nn.CAddTable()({ques_emb_expand_1, img_emb_1})
    -- local h1 = nn.Dropout(drop_ratio)(nn.CAddTable()({ques_emb_expand_1, img_emb_1}))	          -- [batch_size, m, att_size]
    local h1_emb = nn.Linear(att_size, 1)(nn.View(-1,att_size)(h1)) -- [batch_size * m, 1]
    local p1 = nn.SoftMax()(nn.View(-1,img_seq_size)(h1_emb))       -- [batch_size, m]
    local p1_att = nn.View(1,-1):setNumInputDims(1)(p1)             -- [batch_size, 1, m]
    -- Weighted Sum
    local img_Att1 = nn.MM(false, false)({p1_att, img_feat})	    -- [batch_size, 1, d]
    local img_att_feat_1 = nn.View(-1, input_size)(img_Att1)	    -- [batch_size, d]
    local u1 = nn.CAddTable()({ques_feat, img_att_feat_1})	    -- [batch_size, d]


    -- Stack 2
    local ques_emb_2 = nn.Linear(input_size, att_size)(u1)          -- [batch_size, att_size] 
    local ques_emb_expand_2 = nn.Replicate(img_seq_size,2)(ques_emb_2) 	    -- [batch_size, m, att_size]
    local img_emb_dim_2 = nn.Linear(input_size, att_size, false)(nn.View(-1,input_size)(img_feat)) -- [batch_size*m, att_size]
    local img_emb_2 = nn.View(-1, img_seq_size, att_size)(img_emb_dim_2)			          -- [batch_size, m, att_size]
    -- Dropout or not
    local h2 = nn.CAddTable()({ques_emb_expand_2, img_emb_2})
    -- local h2 = nn.Dropout(drop_ratio)(nn.CAddTable()({ques_emb_expand_2, img_emb_2}))    	          -- [batch_size, m, att_size]
    local h2_emb = nn.Linear(att_size, 1)(nn.View(-1,att_size)(h2)) -- [batch_size * m, 1]
    local p2 = nn.SoftMax()(nn.View(-1,img_seq_size)(h2_emb))       -- [batch_size, m]
    local p2_att = nn.View(1,-1):setNumInputDims(1)(p2)             -- [batch_size, 1, m]
    -- Weighted Sum
    local img_Att2 = nn.MM(false, false)({p2_att, img_feat})        -- [batch_size, 1, d]
    local img_att_feat_2 = nn.View(-1, input_size)(img_Att2)        -- [batch_size, d]
    local u2 = nn.CAddTable()({u1, img_att_feat_2})		                  -- [batch_size, d]


    -- Final Answer Prdict
    local score = nn.Linear(input_size, output_size)(u2)	    -- [batch_size, 1000]
    local p_ans = nn.SoftMax()(score) 			            -- [batch_size, 1000]

    table.insert(outputs, p_ans)

    return nn.gModule(inputs, outputs)
end

return attention