---
search:
  exclude: true
---
# 安全防护措施

安全防护措施与智能体并行运行，使你能够对用户输入进行检查和验证。比如，设想你有一个使用非常智能（因此也更慢/更昂贵）模型来处理客户请求的智能体。你不希望恶意用户让该模型帮助他们完成数学作业。因此，你可以使用一个快速/便宜的模型来运行安全防护措施。如果安全防护措施检测到恶意使用，它可以立即抛出错误，从而阻止昂贵模型运行，帮你节省时间/成本。

安全防护措施有两种类型：

1. 输入安全防护措施针对初始用户输入运行
2. 输出安全防护措施针对最终智能体输出运行

## 输入安全防护措施

输入安全防护措施分 3 个步骤运行：

1. 首先，安全防护措施接收与智能体相同的输入。
2. 接着，安全防护函数运行并生成一个[`GuardrailFunctionOutput`][agents.guardrail.GuardrailFunctionOutput]，随后会被包装为一个[`InputGuardrailResult`][agents.guardrail.InputGuardrailResult]
3. 最后，我们检查[`.tripwire_triggered`][agents.guardrail.GuardrailFunctionOutput.tripwire_triggered]是否为 true。如果为 true，会抛出一个[`InputGuardrailTripwireTriggered`][agents.exceptions.InputGuardrailTripwireTriggered]异常，以便你能适当地响应用户或处理该异常。

!!! Note

    输入安全防护措施旨在对用户输入运行，因此只有当该智能体是第一个智能体时，其安全防护措施才会运行。你可能会想，为什么 `guardrails` 属性在智能体上而不是传给 `Runner.run`？这是因为安全防护措施通常与具体的智能体相关——你会为不同的智能体运行不同的安全防护措施，因此将代码就近放置有助于可读性。

## 输出安全防护措施

输出安全防护措施分 3 个步骤运行：

1. 首先，安全防护措施接收由智能体产生的输出。
2. 接着，安全防护函数运行并生成一个[`GuardrailFunctionOutput`][agents.guardrail.GuardrailFunctionOutput]，随后会被包装为一个[`OutputGuardrailResult`][agents.guardrail.OutputGuardrailResult]
3. 最后，我们检查[`.tripwire_triggered`][agents.guardrail.GuardrailFunctionOutput.tripwire_triggered]是否为 true。如果为 true，会抛出一个[`OutputGuardrailTripwireTriggered`][agents.exceptions.OutputGuardrailTripwireTriggered]异常，以便你能适当地响应用户或处理该异常。

!!! Note

    输出安全防护措施旨在对最终的智能体输出运行，因此只有当该智能体是最后一个智能体时，其安全防护措施才会运行。与输入安全防护措施类似，我们这样做是因为安全防护措施通常与具体的智能体相关——你会为不同的智能体运行不同的安全防护措施，因此将代码就近放置有助于可读性。

## 绊线

如果输入或输出未通过安全防护措施，安全防护措施可以通过绊线（tripwire）发出信号。一旦我们发现某个安全防护措施触发了绊线，我们会立即抛出 `{Input,Output}GuardrailTripwireTriggered` 异常并终止智能体执行。

## 安全防护措施实现

你需要提供一个接收输入并返回[`GuardrailFunctionOutput`][agents.guardrail.GuardrailFunctionOutput]的函数。在此示例中，我们将通过在底层运行一个智能体来实现这一点。

```python
from pydantic import BaseModel
from agents import (
    Agent,
    GuardrailFunctionOutput,
    InputGuardrailTripwireTriggered,
    RunContextWrapper,
    Runner,
    TResponseInputItem,
    input_guardrail,
)

class MathHomeworkOutput(BaseModel):
    is_math_homework: bool
    reasoning: str

guardrail_agent = Agent( # (1)!
    name="Guardrail check",
    instructions="Check if the user is asking you to do their math homework.",
    output_type=MathHomeworkOutput,
)


@input_guardrail
async def math_guardrail( # (2)!
    ctx: RunContextWrapper[None], agent: Agent, input: str | list[TResponseInputItem]
) -> GuardrailFunctionOutput:
    result = await Runner.run(guardrail_agent, input, context=ctx.context)

    return GuardrailFunctionOutput(
        output_info=result.final_output, # (3)!
        tripwire_triggered=result.final_output.is_math_homework,
    )


agent = Agent(  # (4)!
    name="Customer support agent",
    instructions="You are a customer support agent. You help customers with their questions.",
    input_guardrails=[math_guardrail],
)

async def main():
    # This should trip the guardrail
    try:
        await Runner.run(agent, "Hello, can you help me solve for x: 2x + 3 = 11?")
        print("Guardrail didn't trip - this is unexpected")

    except InputGuardrailTripwireTriggered:
        print("Math homework guardrail tripped")
```

1. 我们会在安全防护函数中使用此智能体。
2. 这是接收智能体输入/上下文并返回结果的安全防护函数。
3. 我们可以在安全防护结果中包含额外信息。
4. 这是定义工作流的实际智能体。

输出安全防护措施类似。

```python
from pydantic import BaseModel
from agents import (
    Agent,
    GuardrailFunctionOutput,
    OutputGuardrailTripwireTriggered,
    RunContextWrapper,
    Runner,
    output_guardrail,
)
class MessageOutput(BaseModel): # (1)!
    response: str

class MathOutput(BaseModel): # (2)!
    reasoning: str
    is_math: bool

guardrail_agent = Agent(
    name="Guardrail check",
    instructions="Check if the output includes any math.",
    output_type=MathOutput,
)

@output_guardrail
async def math_guardrail(  # (3)!
    ctx: RunContextWrapper, agent: Agent, output: MessageOutput
) -> GuardrailFunctionOutput:
    result = await Runner.run(guardrail_agent, output.response, context=ctx.context)

    return GuardrailFunctionOutput(
        output_info=result.final_output,
        tripwire_triggered=result.final_output.is_math,
    )

agent = Agent( # (4)!
    name="Customer support agent",
    instructions="You are a customer support agent. You help customers with their questions.",
    output_guardrails=[math_guardrail],
    output_type=MessageOutput,
)

async def main():
    # This should trip the guardrail
    try:
        await Runner.run(agent, "Hello, can you help me solve for x: 2x + 3 = 11?")
        print("Guardrail didn't trip - this is unexpected")

    except OutputGuardrailTripwireTriggered:
        print("Math output guardrail tripped")
```

1. 这是实际智能体的输出类型。
2. 这是安全防护措施的输出类型。
3. 这是接收智能体输出并返回结果的安全防护函数。
4. 这是定义工作流的实际智能体。