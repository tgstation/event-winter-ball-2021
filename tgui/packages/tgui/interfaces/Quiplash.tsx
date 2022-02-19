import { useBackend } from '../backend';
import { Button, LabeledList, Section, Table, Icon } from '../components';
import { Window } from '../layouts';

type QuiplashData = {
  state : string
  admin : boolean
  leaderboard: object
}

export const Quiplash = (_, context) => {
  const { act, data } = useBackend<QuiplashData>(context);

  const scores = Object
    .keys(data.leaderboard)
    .map(key => ({
      name: key,
      value: data.leaderboard[key],
    }));
  return (
    <Window
      title="Quiplash Panel"
      width={300}
      height={500}>
      <Window.Content scrollable>
        {!!data.admin && (
          <Section title="Admin">
            <LabeledList>
              <LabeledList.Item label="Game State">
                {data.state}
              </LabeledList.Item>
            </LabeledList>
            <Button onClick={() => act("pause")}>{data.state !== "paused" ? "Pause" : "Unpause"}</Button>
            <Button onClick={() => act("force_prompt")}>Force next prompt</Button>
          </Section>)}
        <Section title="Top Punsters">
          <Table>
            <Table.Row header>
              <Table.Cell textAlign="center">
                #
              </Table.Cell>
              <Table.Cell textAlign="center">
                Name
              </Table.Cell>
              <Table.Cell textAlign="center">
                Score
              </Table.Cell>
            </Table.Row>
            {scores.map((score, i) => (
              <Table.Row
                key={score.name}
                className="candystripe"
                m={2}>
                <Table.Cell color="label" textAlign="center">
                  {i + 1}
                </Table.Cell>
                <Table.Cell textAlign="center">
                  {i === 0 && (
                    <Icon name="crown" color="yellow" mr={2} />
                  )}
                  {score.name}
                  {i === 0 && (
                    <Icon name="crown" color="yellow" ml={2} />
                  )}
                </Table.Cell>
                <Table.Cell textAlign="center">
                  {score.value}
                </Table.Cell>
              </Table.Row>
            ))}
          </Table>
        </Section>
      </Window.Content>
    </Window>
  );
};
