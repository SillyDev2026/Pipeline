--!native
--!optimize 2

export type Context = { [string]: any }

-- Core function types
export type StageFn<I, O> = (input: I, ctx: Context) -> O
export type BranchConditionFn<I> = (input: I, ctx: Context) -> string

-- Forward declare Pipeline
export type Pipeline<I, O> = {
	stages: { Stage<any, any> },
	context: Context,
	hooks: {
		beforeStage: ((label: string, value: any, ctx: Context) -> ())?,
		afterStage: ((label: string, value: any, ctx: Context) -> ())?,
	},
	mergeFn: ((results: {any}, ctx: Context) -> any)?,
	catchFn: ((err: any, ctx: Context) -> any)?,
	finallyFn: ((result: any, ctx: Context) -> ())?,
	step: <N>(self: Pipeline<I, O>, fn: StageFn<O, N>, label: string?) -> Pipeline<I, N>,
	parallel: <N>(self: Pipeline<I, O>, fns: {StageFn<O, N>}, label: string?) -> Pipeline<I, N>,
	branch: <N>(self: Pipeline<I, O>, condFn: BranchConditionFn<O>, branches: { [string]: Pipeline<O, N> }, label: string?) -> Pipeline<I, N>,
	filter: (self: Pipeline<I, O>, fn: StageFn<O, boolean>, label: string?) -> Pipeline<I, O>,
	repeatStage: (self: Pipeline<I, O>, stageFn: StageFn<O, O>, condFn: BranchConditionFn<O>, label: string?) -> Pipeline<I, O>,
	merge: (self: Pipeline<I, O>, fn: (results: {any}, ctx: Context) -> O) -> Pipeline<I, O>,
	catch: (self: Pipeline<I, O>, fn: (err: any, ctx: Context) -> O) -> Pipeline<I, O>,
	finally: (self: Pipeline<I, O>, fn: (result: O, ctx: Context) -> ()) -> Pipeline<I, O>,
	hooksFn: (
		self: Pipeline<I, O>,
		hooks: {
			beforeStage: ((string, any, Context) -> ())?,
			afterStage: ((string, any, Context) -> ())?
		}
	) -> Pipeline<I, O>,

	run: (self: Pipeline<I, O>, input: I) -> (O, Context),
}

export type Branches<I, O> = { [string]: Pipeline<I, O> }

export type Stage<I, O> = {
	type: "step" | "parallel" | "branch" | "filter" | "repeat",

	fn: StageFn<I, O>?,
	fns: {StageFn<I, O>}?,
	stageFn: StageFn<I, O>?,

	conditionFn: BranchConditionFn<I>?,
	branches: { [string]: Pipeline<I, O> }?,

	label: string?,
}

local Pipeline = {}
Pipeline.__index = Pipeline

local HALT = {}

function Pipeline.new<T>(): Pipeline<T, T>
	return setmetatable({
		stages = {},
		context = {},
		hooks = { beforeStage = nil, afterStage = nil },
		mergeFn = nil,
		catchFn = nil,
		finallyFn = nil,
	}, Pipeline) :: any
end

function Pipeline.step<I, O, N>(
	self: Pipeline<I, O>,
	fn: StageFn<O, N>,
	label: string?
): Pipeline<I, N>

	table.insert(self.stages, {
		type = "step",
		fn = fn,
		label = label,
	})

	return (self :: any) :: Pipeline<I, N>
end

function Pipeline.parallel<I, O, N>(
	self: Pipeline<I, O>,
	fns: { StageFn<O, N> },
	label: string?
): Pipeline<I, N>

	table.insert(self.stages, {
		type = "parallel",
		fns = fns,
		label = label,
	})

	return (self :: any) :: Pipeline<I, N>
end

-- Branch (O -> N)
function Pipeline.branch<I, O, N>(
	self: Pipeline<I, O>,
	condFn: BranchConditionFn<O>,
	branches: { [string]: Pipeline<O, N> },
	label: string?
): Pipeline<I, N>

	table.insert(self.stages, {
		type = "branch",
		conditionFn = condFn,
		branches = branches,
		label = label,
	})

	return (self :: any) :: Pipeline<I, N>
end

-- Filter (O -> O)
function Pipeline.filter<I, O>(
	self: Pipeline<I, O>,
	fn: StageFn<O, boolean>,
	label: string?
): Pipeline<I, O>

	table.insert(self.stages, {
		type = "filter",
		fn = fn,
		label = label,
	})

	return self
end

-- Repeat (O -> O)
function Pipeline.repeatStage<I, O>(
	self: Pipeline<I, O>,
	stageFn: StageFn<O, O>,
	condFn: BranchConditionFn<O>,
	label: string?
): Pipeline<I, O>

	table.insert(self.stages, {
		type = "repeat",
		stageFn = stageFn,
		conditionFn = condFn,
		label = label,
	})

	return self
end

-- Merge (keeps O)
function Pipeline.merge<I, O>(
	self: Pipeline<I, O>,
	fn: (results: { any }, ctx: Context) -> O
): Pipeline<I, O>

	self.mergeFn = fn
	return self
end

-- Hooks
function Pipeline.hooksFn<I, O>(
	self: Pipeline<I, O>,
	hooks: {
		beforeStage: ((string, any, Context) -> ())?,
		afterStage: ((string, any, Context) -> ())?,
	}
): Pipeline<I, O>

	self.hooks = hooks
	return self
end

-- Catch (forces return to O)
function Pipeline.catch<I, O>(
	self: Pipeline<I, O>,
	fn: (err: any, ctx: Context) -> O
): Pipeline<I, O>

	self.catchFn = fn
	return self
end

-- Finally
function Pipeline.finally<I, O>(
	self: Pipeline<I, O>,
	fn: (result: O, ctx: Context) -> ()
): Pipeline<I, O>

	self.finallyFn = fn
	return self
end

-- Run
function Pipeline.run<I, O>(
	self: Pipeline<I, O>,
	input: I
): (O, Context)

	local result: any = input
	local ctx = self.context

	local function runStage(stage: Stage<any, any>)
		if self.hooks.beforeStage then
			self.hooks.beforeStage(stage.label or stage.type, result, ctx)
		end

		local val: any

		if stage.type == "step" and stage.fn then
			val = stage.fn(result, ctx)

		elseif stage.type == "parallel" and stage.fns then
			local results = {}
			for i, fn in ipairs(stage.fns) do
				results[i] = fn(result, ctx)
			end
			val = self.mergeFn and self.mergeFn(results, ctx) or results

		elseif stage.type == "branch" and stage.conditionFn and stage.branches then
			local key = stage.conditionFn(result, ctx)
			local branchPipeline = stage.branches[key] or stage.branches["other"]

			if branchPipeline then
				local branchResult = branchPipeline:run(result)
				val = branchResult
			else
				val = result
			end

		elseif stage.type == "filter" and stage.fn then
			val = stage.fn(result, ctx) and result or HALT

		elseif stage.type == "repeat" and stage.stageFn and stage.conditionFn then
			local loopResult = result
			while stage.conditionFn(loopResult, ctx) do
				loopResult = stage.stageFn(loopResult, ctx)
			end
			val = loopResult

		else
			val = result
		end

		if self.hooks.afterStage then
			self.hooks.afterStage(stage.label or stage.type, val, ctx)
		end

		return val
	end

	for _, stage in ipairs(self.stages) do
		local ok, val = pcall(runStage, stage)

		if ok then
			if val == HALT then break end
			result = val
		else
			if self.catchFn then
				return self.catchFn(val, ctx), ctx
			else
				error(val)
			end
		end
	end

	if self.finallyFn then
		self.finallyFn(result, ctx)
	end

	return result :: O, ctx
end

return Pipeline
