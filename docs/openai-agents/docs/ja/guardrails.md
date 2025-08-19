---
search:
  exclude: true
---
# ガードレール

ガードレールはエージェントと _並行して_ 実行され、ユーザー入力のチェックや検証を可能にします。たとえば、顧客の問い合わせを支援するために非常に賢い（そのため遅く/高価な）モデルを使うエージェントがあるとします。悪意のあるユーザーが数学の宿題を手伝うようモデルに依頼することは避けたいはずです。そこで、速く/安価なモデルでガードレールを実行できます。ガードレールが悪意のある使用を検出した場合、即座にエラーを発生させ、コストの高いモデルの実行を停止して時間と費用を節約できます。

ガードレールには 2 つの種類があります:

1. 入力ガードレールは最初のユーザー入力で実行されます
2. 出力ガードレールは最終的なエージェント出力で実行されます

## 入力ガードレール

入力ガードレールは 3 ステップで実行されます:

1. まず、ガードレールはエージェントに渡されたものと同じ入力を受け取ります。
2. 次に、ガードレール関数が実行され、[`GuardrailFunctionOutput`][agents.guardrail.GuardrailFunctionOutput] を生成し、それを [`InputGuardrailResult`][agents.guardrail.InputGuardrailResult] にラップします。
3. 最後に、[`.tripwire_triggered`][agents.guardrail.GuardrailFunctionOutput.tripwire_triggered] が true かどうかを確認します。true の場合、[`InputGuardrailTripwireTriggered`][agents.exceptions.InputGuardrailTripwireTriggered] 例外が発生し、ユーザーへの適切な応答や例外処理ができます。

!!! Note

    入力ガードレールはユーザー入力で実行されることを想定しているため、エージェントのガードレールはそのエージェントが最初のエージェントである場合にのみ実行されます。なぜ `guardrails` プロパティがエージェント上にあり、`Runner.run` に渡さないのか疑問に思うかもしれません。これは、ガードレールが実際のエージェントに関連する傾向があるためです。エージェントごとに異なるガードレールを実行するため、コードを同じ場所に置くことで可読性が向上します。

## 出力ガードレール

出力ガードレールは 3 ステップで実行されます:

1. まず、ガードレールはエージェントによって生成された出力を受け取ります。
2. 次に、ガードレール関数が実行され、[`GuardrailFunctionOutput`][agents.guardrail.GuardrailFunctionOutput] を生成し、それを [`OutputGuardrailResult`][agents.guardrail.OutputGuardrailResult] にラップします。
3. 最後に、[`.tripwire_triggered`][agents.guardrail.GuardrailFunctionOutput.tripwire_triggered] が true かどうかを確認します。true の場合、[`OutputGuardrailTripwireTriggered`][agents.exceptions.OutputGuardrailTripwireTriggered] 例外が発生し、ユーザーへの適切な応答や例外処理ができます。

!!! Note

    出力ガードレールは最終的なエージェント出力で実行されることを想定しているため、エージェントのガードレールはそのエージェントが最後のエージェントである場合にのみ実行されます。入力ガードレールと同様に、ガードレールは実際のエージェントに関連する傾向があるため、コードを同じ場所に置くことで可読性が向上します。

## トリップワイヤー

入力または出力がガードレールに不合格となった場合、ガードレールはトリップワイヤーでそれを示せます。トリップワイヤーが発火したガードレールを検知するとすぐに `{Input,Output}GuardrailTripwireTriggered` 例外を送出し、エージェントの実行を停止します。

## ガードレールの実装

入力を受け取り、[`GuardrailFunctionOutput`][agents.guardrail.GuardrailFunctionOutput] を返す関数を用意する必要があります。次の例では、内部でエージェントを実行してこれを行います。

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

1. このエージェントをガードレール関数で使用します。
2. これはエージェントの入力/コンテキストを受け取り、結果を返すガードレール関数です。
3. ガードレール結果に追加情報を含められます。
4. これはワークフローを定義する実際のエージェントです。

出力ガードレールも同様です。

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

1. これは実際のエージェントの出力型です。
2. これはガードレールの出力型です。
3. これはエージェントの出力を受け取り、結果を返すガードレール関数です。
4. これはワークフローを定義する実際のエージェントです。